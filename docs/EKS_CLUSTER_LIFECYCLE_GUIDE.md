<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
## 目录 (Table of Contents)

- [EKS 云原生集群生命周期流程文档](#eks-%E4%BA%91%E5%8E%9F%E7%94%9F%E9%9B%86%E7%BE%A4%E7%94%9F%E5%91%BD%E5%91%A8%E6%9C%9F%E6%B5%81%E7%A8%8B%E6%96%87%E6%A1%A3)
  - [准备工作](#%E5%87%86%E5%A4%87%E5%B7%A5%E4%BD%9C)
    - [本地依赖要求](#%E6%9C%AC%E5%9C%B0%E4%BE%9D%E8%B5%96%E8%A6%81%E6%B1%82)
    - [AWS SSO 登录](#aws-sso-%E7%99%BB%E5%BD%95)
  - [集群每日重建流程](#%E9%9B%86%E7%BE%A4%E6%AF%8F%E6%97%A5%E9%87%8D%E5%BB%BA%E6%B5%81%E7%A8%8B)
  - [日常关闭资源以节省成本](#%E6%97%A5%E5%B8%B8%E5%85%B3%E9%97%AD%E8%B5%84%E6%BA%90%E4%BB%A5%E8%8A%82%E7%9C%81%E6%88%90%E6%9C%AC)
  - [一键彻底销毁所有资源](#%E4%B8%80%E9%94%AE%E5%BD%BB%E5%BA%95%E9%94%80%E6%AF%81%E6%89%80%E6%9C%89%E8%B5%84%E6%BA%90)
  - [查看日志与清理状态](#%E6%9F%A5%E7%9C%8B%E6%97%A5%E5%BF%97%E4%B8%8E%E6%B8%85%E7%90%86%E7%8A%B6%E6%80%81)
    - [查看最近执行日志](#%E6%9F%A5%E7%9C%8B%E6%9C%80%E8%BF%91%E6%89%A7%E8%A1%8C%E6%97%A5%E5%BF%97)
    - [清理状态缓存文件（可选）](#%E6%B8%85%E7%90%86%E7%8A%B6%E6%80%81%E7%BC%93%E5%AD%98%E6%96%87%E4%BB%B6%E5%8F%AF%E9%80%89)
  - [推荐 gitignore 配置](#%E6%8E%A8%E8%8D%90-gitignore-%E9%85%8D%E7%BD%AE)
  - [后续规划](#%E5%90%8E%E7%BB%AD%E8%A7%84%E5%88%92)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# EKS 云原生集群生命周期流程文档

- **最后更新**: August 17, 2025, 16:19 (UTC+08:00)
- **作者**: 张人大（Renda Zhang）

本文档记录从初始化到销毁的全生命周期操作流程，适用于开发、测试和生产演练场景。

---

## 准备工作

### 本地依赖要求

请先确保本地已安装如下工具：

| 工具        | 说明             |
| --------- | -------------- |
| AWS CLI   | 用于账户授权与状态查询    |
| Terraform | IaC 主引擎，管理资源声明 |
| Helm      | 可选，管理集群内组件     |

执行以下命令检查并按需安装 CLI 工具：

```bash
make check
# 或跳过提示直接安装
make check-auto
```

### AWS SSO 登录

使用以下命令登录 AWS：

```bash
make aws-login
```

---

## 集群每日重建流程

```bash
make init
make start-all
```

如需启用 Chaos Mesh，请在执行命令时加上 `ENABLE_CHAOS_MESH=true`，例如：

```bash
ENABLE_CHAOS_MESH=true make start-all
```

---

## 日常关闭资源以节省成本

```bash
make stop-all
```

---

## 一键彻底销毁所有资源

适用于彻底重建或环境迁移：

```bash
make destroy-all
```

---

## 查看日志与清理状态

### 查看最近执行日志

```bash
make logs
```

### 清理状态缓存文件（可选）

```bash
make clean
```

---

## 推荐 gitignore 配置

```gitignore
scripts/.last-asg-bound
scripts/logs/*
!scripts/logs/.gitkeep
```

---

## 后续规划

- 整合 GitHub Actions 自动执行 `make start-all`
