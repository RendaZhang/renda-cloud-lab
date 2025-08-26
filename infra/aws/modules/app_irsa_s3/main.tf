// ---------------------------
// 应用级云权限模块：S3 桶 + IRSA Role
// ---------------------------

locals {
  bucket_name = coalesce( # 若未指定则生成唯一桶名
    var.s3_bucket_name,
    "${var.cluster_name}-${var.app_name}-${random_pet.bucket_suffix.id}"
  )
  oidc_url_without_https = var.oidc_provider_url == null ? null : replace(var.oidc_provider_url, "https://", "")
}

resource "random_pet" "bucket_suffix" {
  length    = 2
  separator = "-"
}

# --- S3 Bucket ---
resource "aws_s3_bucket" "this" {
  bucket = local.bucket_name # S3 桶名称

  tags = {
    Application = var.app_name     # 所属应用
    Environment = var.cluster_name # 环境/集群名
    Region      = var.region       # 部署区域
  }

  lifecycle {
    prevent_destroy = true # 避免每日销毁流程误删
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id # 绑定到上方桶
  block_public_acls       = true                  # 禁止 Public ACL
  block_public_policy     = true                  # 禁止 Public Policy
  ignore_public_acls      = true                  # 忽略已有的 Public ACL
  restrict_public_buckets = true                  # 阻止公共桶
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced" # 统一所有权语义
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # 默认使用 SSE-S3 加密
    }
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled" # 打开版本控制以便审计回滚
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  # 仅清理临时 smoke 前缀，避免误删业务数据
  rule {
    id     = "cleanup-smoke"
    status = "Enabled"

    filter {
      prefix = "${var.s3_prefix}smoke/" # 目标前缀：<prefix>smoke/
    }

    expiration {
      days = 7 # 7 天后自动过期
    }

    noncurrent_version_expiration {
      noncurrent_days = 7 # 清理旧版本
    }
  }
}

# --- Bucket Policy ---
data "aws_iam_policy_document" "bucket" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    # 仅“数据面”动作：
    # - 避免阻断管理面（Get/PutBucketPolicy、PutBucketLifecycleConfiguration 等）
    # - 避免刷新时从公网端点读取桶信息被 403
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  dynamic "statement" {
    for_each = var.vpc_id == null ? [] : [var.vpc_id]
    content {
      sid    = "DenyNonVpc"
      effect = "Deny"
      principals {
        type        = "*"
        identifiers = ["*"]
      }
      # 同样只覆盖“数据面”动作
      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ]
      resources = [
        aws_s3_bucket.this.arn,
        "${aws_s3_bucket.this.arn}/*"
      ]
      condition {
        # IfExists 避免在没有 SourceVpc 上下文（例如公网端点）时被误判为“不等”
        test     = "StringNotEqualsIfExists"
        variable = "aws:SourceVpc"
        values   = [var.vpc_id]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.bucket.json
}

# --- IAM Policy ---
resource "aws_iam_policy" "this" {
  count       = var.create_irsa ? 1 : 0 # 仅在需要 IRSA 时创建策略
  name        = "${var.cluster_name}-${var.app_name}-s3"
  description = "Minimal S3 access for ${var.app_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.this.arn
        Condition = {
          StringLike = {
            "s3:prefix" = ["${var.s3_prefix}*"]
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = "${aws_s3_bucket.this.arn}/${var.s3_prefix}*"
      }
    ]
  })
}

# --- IRSA Role ---
resource "aws_iam_role" "this" {
  count       = var.create_irsa ? 1 : 0 # 控制 IRSA 角色创建
  name        = "${var.cluster_name}-${var.app_name}-irsa"
  description = "IRSA role for ${var.app_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${local.oidc_url_without_https}:aud" = "sts.amazonaws.com"
            "${local.oidc_url_without_https}:sub" = "system:serviceaccount:${var.namespace}:${var.sa_name}"
          }
        }
      }
    ]
  })

  lifecycle {
    create_before_destroy = true # 确保替换时先建后删
  }
}

resource "aws_iam_role_policy_attachment" "this" {
  count      = var.create_irsa ? 1 : 0 # 仅在创建 IRSA 时附加策略
  role       = aws_iam_role.this[0].name
  policy_arn = aws_iam_policy.this[0].arn

  lifecycle {
    create_before_destroy = true
  }
}
