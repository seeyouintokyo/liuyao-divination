#!/bin/bash
# ============================================================
# 六爻起卦 — 部署脚本（供 aliyun appmanager ECS 一键部署使用）
# 项目：liuyao-divination（纯静态单页）
# 地域：cn-beijing  目标实例：i-f8z4nozc5klw0izmrtq7
# ============================================================
# 用法（在你自己的终端里按顺序跑）：
#
#   cd /Users/xingyang/Downloads/code/sumsara/01_通用算卦网站/liuyao-divination
#   export SKILL_DIR="$HOME/.codex/skills/alibabacloud-ecs-code-deploy"
#   export SESSION_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
#   export ALIBABA_CLOUD_USER_AGENT="AlibabaCloud-Agent-Skills/alibabacloud-ecs-code-deploy/${SESSION_ID}"
#
#   # 1. 环境预检
#   python3 "$SKILL_DIR/scripts/deploy_toolkit.py" check
#
#   # 2. 初始化（生成 .appmanager/config.yaml）
#   aliyun appmanager init --non-interactive \
#     --name liuyao-divination --type app \
#     --ecs existing --instance-id i-f8z4nozc5klw0izmrtq7 \
#     --region cn-beijing --port 8080
#
#   # 3. 写入启停脚本（本文件第 2 部分）
#   # 4. 询价
#   python3 "$SKILL_DIR/scripts/deploy_toolkit.py" price --config .appmanager/config.yaml
#   # 5. 部署
#   python3 "$SKILL_DIR/scripts/deploy_toolkit.py" deploy \
#     --type app --name liuyao-divination --group liuyao --region cn-beijing
#   # 6. 验证
#   python3 "$SKILL_DIR/scripts/deploy_toolkit.py" verify \
#     --type app --name liuyao-divination --group liuyao --region cn-beijing
# ============================================================
