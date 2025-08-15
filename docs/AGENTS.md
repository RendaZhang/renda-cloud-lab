<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
## 目录 (Table of Contents)

- [Guidance for AI Agents](#guidance-for-ai-agents)
  - [Project Overview](#project-overview)
  - [Key Project Structure](#key-project-structure)
  - [Rules for Modification](#rules-for-modification)
  - [Context to Remember](#context-to-remember)
  - [Allowed Actions](#allowed-actions)
  - [FAQs](#faqs)
  - [Last Notes](#last-notes)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Guidance for AI Agents

- **Purpose:** This file describes how an AI agent (e.g. OpenAI Codex, DevAgent, etc.) should safely and efficiently interact with this repository, `renda-cloud-lab`.
- **Last Updated:** July 18, 2025, 22:00 (UTC+08:00)
- **Maintainer:** Renda Zhang (张人大)
- **Environment:** AWS Cloud, Terraform, EKS, Helm, GitOps

---

## Project Overview

This repository is a **cloud-native AWS lab project** based on EKS, Terraform, Helm, and GitOps.

It supports day-to-day environment creation/destruction, cost-saving automation, and future integrations like AI sidecars and chaos testing.

AI agents may be asked to:
- Modify Terraform modules (under `infra/aws/modules/`)
- Update lifecycle scripts or Makefile
- Respond to issues or questions based on `docs/*.md`
- Refactor configuration (`*.tf`, `*.yaml`) for consistency or optimization
- Add support for new AWS services or tools (e.g., Bedrock, Karpenter, etc.)

---

## Key Project Structure

```text
renda-cloud-lab/
├── infra/                  # Infrastructure-as-Code
│   ├── aws/                # Terraform-based IaC modules
│   └── eksctl/             # Initial eksctl cluster config (legacy)
├── charts/                 # Helm Charts for workloads & system components
├── scripts/                # Shell automation: setup, import, teardown
├── docs/                   # Documentation
├── diagrams/               # Terraform graphviz architecture
├── Makefile                # Declarative commands to orchestrate lab
└── README.md               # README file for project
```

---

## Rules for Modification

| Area             | Guidelines                |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `infra/aws/`     | **Use Terraform best practices**. Do not directly edit `.terraform` or state. Modules follow `create_*` toggle flags (e.g., `create_nat`). |
| `infra/eksctl/`  | Legacy samples. Terraform now fully manages EKS. Only touch when `create_eks=false` workflows are discussed.   |
| `scripts/`       | Keep shell scripts POSIX-compliant and idempotent. Side-effects must be logged to `scripts/logs/` if applicable.  |
| `Makefile`       | Use existing patterns. Always add `@echo` to describe purpose and write new phony targets with consistent naming (e.g., `start`, `stop-hard`). |
| `docs/`          | All documentation follow `.md` formatting conventions.   |
| `.gitignore`     | Do not track log/temp/cache/state files. Log outputs go to `scripts/logs/`.   |
| Terraform `*.tf` | Variables defined in `variables.tf` must have default values unless required. Use modules inside `modules/` when possible.     |

---

## Context to Remember

- Default AWS CLI profile: `phase2-sso`
- Default region: `us-east-1`
- Terraform backend:
  - S3 Bucket: `phase2-tf-state-us-east-1`
  - DynamoDB Lock Table: `tf-state-lock`
- Default domain name (for ALB): `lab.rendazhang.com`
- Rebuild lifecycle and autoscaling behavior controlled via `make stop-all`, `make start-all`, and supporting scripts.
- Login helper command: `make aws-login`
- Import existing clusters via `scripts/tf-import.sh`
- Post-recreate automation script: `scripts/post-recreate.sh` (updates kubeconfig & installs autoscaler)

---

## Allowed Actions

AI agents are allowed to:

- Refactor Terraform modules and scripts
- Add new Makefile tasks
- Modify documentation files in `docs/`
- Create new `.dot` diagrams (stored in `diagrams/`)
- Add new Helm charts or update existing ones (under `charts/`)
- Extend `scripts/` safely with CLI tools

**Agents are not allowed to:**

- Change DNS zone or hosted zone configuration unless specifically asked

---

## FAQs

**How should I update or destroy EKS resources?**
- Only via Terraform.
- Avoid `eksctl` unless creating from scratch and explicitly told to do so.

**Where should temporary logs or cache files go?**
- Use `scripts/logs/`.
- They are `.gitignore`d.

**Can I create a new module for AWS service X?**
- Yes — place it in `infra/aws/modules/` and add a wrapper call in `main.tf`.

**Can I modify AGENTS.md itself?**
- Yes — if additional capabilities are added or team conventions evolve.

---

## Last Notes

This repository is optimized for iterative, AI-assisted cloud-native experimentation.

Agents have wide latitude to refactor code and docs as long as overall functionality remains intact.

Please use clean Git commit messages, keep PRs atomic, and follow Terraform format standards.
