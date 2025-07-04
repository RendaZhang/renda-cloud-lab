# Terraform 基础设施架构图 (Terraform Infrastructure Diagram)

本目录包含 Terraform 基础设施的可视化依赖图，帮助理解资源之间的关系和依赖。
This directory stores visual dependency graphs for Terraform, making it easier to understand resource relationships.

## 文件说明 (File Overview)

| 文件名 | 格式 | 用途 | 更新命令 |
|--------|------|------|----------|
| `terraform-architecture.dot` | Graphviz DOT | 原始依赖图数据 | `terraform graph > terraform-architecture.dot` |
| `terraform-architecture.svg` | SVG 矢量图 | 高清晰度架构图（推荐） | `terraform graph \| dot -Tsvg > terraform-architecture.svg` |
| `terraform-architecture.png` | PNG 位图 | 快速预览图 | `terraform graph \| dot -Tpng > terraform-architecture.png` |

## 如何重新生成图表 (How to Regenerate)

### 基本步骤 (Basic Steps)

1. 导航到 Terraform 目录：
   ```bash
   cd /mnt/d/renda-cloud-lab/infra/aws
   ```

2. 确保 Terraform 状态是最新的：
   ```bash
   terraform init -upgrade
   terraform refresh
   ```

3. 重新生成所有图表：
   ```bash
   # 生成 DOT 文件
   terraform graph > ../../../diagrams/terraform-architecture.dot

   # 生成 SVG (矢量图)
   terraform graph | dot -Tsvg > ../../../diagrams/terraform-architecture.svg

   # 生成 PNG (位图)
   terraform graph | dot -Tpng > ../../../diagrams/terraform-architecture.png
   ```

### 一键更新脚本 (Update Script)

项目根目录提供了便捷脚本 (`scripts/update-diagrams.sh`)。

使用方法：
```bash
# 添加执行权限
chmod +x scripts/update-diagrams.sh

# 运行脚本
./scripts/update-diagrams.sh
```

### 高级选项 (Advanced Options)

#### 1. 生成简化视图 (Simplified View)
```bash
terraform graph -draw-cycles -module-depth=1 | \
  dot -Tsvg -Granksep=1.5 -Nfontsize=10 > ../../../diagrams/simplified-architecture.svg
```

#### 2. 生成交互式 HTML (Interactive HTML)
```bash
terraform graph | dot -Thtml > ../../../diagrams/interactive-architecture.html
```

#### 3. 使用 Rover 生成高级图 (Using Rover)
```bash
# 安装 Rover (https://github.com/im2nguyen/rover)
brew install im2nguyen/tap/rover

# 生成图
rover -tfPath terraform -generateImage -imagePath ../../../diagrams/rover-architecture.png
```

## 图表解读指南 (Interpreting the Graph)

1. **元素含义**：
   - 矩形框：Terraform 资源
   - 虚线框：Terraform 模块
   - 箭头：资源依赖关系（A → B 表示 A 依赖于 B）
   - 菱形：数据源（data sources）

2. **关键模块**：
   - `module.network_base`：VPC/子网/路由等网络基础
   - `module.eks`：EKS 集群和节点组
   - `module.irsa`：IAM 角色和服务账户绑定
   - `module.alb`：应用负载均衡器

3. **主要依赖路径**：
   ```mermaid
   graph LR
     network[网络基础] --> eks[EKS集群]
     eks --> oidc[OIDC提供者]
     oidc --> irsa[IRSA角色]
     irsa --> autoscaler[集群自动扩缩]
     network --> alb[负载均衡器]
     alb --> dns[DNS记录]
   ```

## 最佳实践 (Best Practices)

1. **何时更新**：
   - Terraform 配置有重大变更后
   - 添加/删除模块或资源后
   - 准备架构评审会议前

2. **版本控制**：
   ```bash
   # 提交更新
   git add diagrams/
   git commit -m "更新基础设施架构图"
   ```

3. **可视化工具推荐**：
   - [Graphviz Online](https://dreampuf.github.io/GraphvizOnline/)：在线查看 DOT 文件
   - [Inkscape](https://inkscape.org/)：编辑 SVG 文件
   - [Rover](https://github.com/im2nguyen/rover)：交互式 Terraform 可视化

> 注意：图表生成依赖 Graphviz，安装命令：`sudo apt-get install graphviz` (Linux/WSL) 或 `brew install graphviz` (macOS)
