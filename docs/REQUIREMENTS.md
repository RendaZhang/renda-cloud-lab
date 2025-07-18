<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
## 目录 (Table of Contents)

- [开发环境要求](#%E5%BC%80%E5%8F%91%E7%8E%AF%E5%A2%83%E8%A6%81%E6%B1%82)
  - [pre-commit 钩子](#pre-commit-%E9%92%A9%E5%AD%90)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# 开发环境要求

- **Last Updated:** July 18, 2025, 22:20 (UTC+8)
- **作者:** 张人大（Renda Zhang）

本文档汇总了开发本项目所需的基础工具和脚本依赖。

## pre-commit 钩子

- 仓库使用 pre-commit 管理代码风格和格式。
- 新增 `update-doctoc` 本地钩子，在每次 commit 前自动运行 `scripts/run-doctoc.sh`。
- 脚本会执行 `doctoc README.md docs/*.md`，若本地未安装 doctoc 则会自动跳过。
