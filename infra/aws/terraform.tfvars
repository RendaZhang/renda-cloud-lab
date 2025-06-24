region              = "ap-southeast-1"

vpc_id              = "vpc-0e707170d90e574bb"

public_subnet_ids   = [
  "subnet-0adce896a95ae6ab7",  # 10.0.0.0/20
  "subnet-000870be5da72e278"   # 10.0.16.0/20
]

private_subnet_ids  = [
  "subnet-0461e45bcf90adb45",  # 10.0.128.0/20
  "subnet-0e3fe8091cbf2622d"   # 10.0.144.0/20
]

eks_admin_role_arn  = "arn:aws:iam::563149051155:role/eks-admin-role"
