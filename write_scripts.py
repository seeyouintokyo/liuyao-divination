#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把启停脚本写入 .appmanager/config.yaml

用法：
    python3 write_scripts.py

前置：已经跑过 `aliyun appmanager init`，存在 .appmanager/config.yaml
"""
import os
import sys

try:
    import yaml
except ImportError:
    print("缺少 pyyaml，请先跑： pip3 install pyyaml")
    sys.exit(1)

APP_NAME = "liuyao-divination"
CONFIG = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".appmanager", "config.yaml")

# ---------------------------------------------------------------
# 启动脚本
# 关键点（按 skill 规范）：
#   1. 必须解压 zip（appmanager 上传但不解压）
#   2. 日志固定 /root/app.log，PID 固定 /root/app.pid
#   3. nohup 后台运行，日志用 >>
#   4. 结尾必须 cat 日志供 verify 抓取
#   5. APP_DIR = /root/{app_name}
#   6. 不得使用 heredoc
# ---------------------------------------------------------------
START = """#!/bin/bash
set -e
APP_DIR=/root/liuyao-divination
ZIP_FILE=$(ls /root/project_*.zip 2>/dev/null | tail -1)
LOG_FILE=/root/app.log
PID_FILE=/root/app.pid

echo "=== [liuyao] deploy start $(date) ==="

# 停掉旧进程
[ -f "$PID_FILE" ] && kill "$(cat $PID_FILE)" 2>/dev/null || true
rm -f "$PID_FILE"

# 释放 8080：清掉可能残留的 http.server（上次部署遗留）
pkill -f "http.server 8080" 2>/dev/null || true
sleep 2

# 包管理器探测
if command -v dnf &>/dev/null; then
  PKG_MGR="dnf"
elif command -v yum &>/dev/null; then
  PKG_MGR="yum"
elif command -v apt-get &>/dev/null; then
  PKG_MGR="apt-get"
else
  echo "ERROR: No supported package manager found" && exit 1
fi

# 装 unzip
if ! command -v unzip &>/dev/null; then
  $PKG_MGR install -y unzip
fi

# 装 python3（静态站用它起 http.server）
if ! command -v python3 &>/dev/null; then
  if [ "$PKG_MGR" = "apt-get" ]; then
    apt-get update -qq && apt-get install -y -qq python3
  else
    $PKG_MGR install -y python3
  fi
fi

# 解压（必须！appmanager 上传 zip 但不解压）
mkdir -p "$APP_DIR"
if [ -n "$ZIP_FILE" ]; then
  unzip -o "$ZIP_FILE" -d "$APP_DIR"
else
  echo "ERROR: no project zip found under /root/" && exit 1
fi

cd "$APP_DIR"
echo "=== [liuyao] files ready, ls: ==="
ls -la

# 起静态服务
# 注意：不用 --directory 参数（Python < 3.7 不支持），改为 cd 进目录再起
# 显式绑 0.0.0.0，否则只监听 127.0.0.1，安全组放行了也访问不到
cd "$APP_DIR"
nohup python3 -m http.server 8080 --bind 0.0.0.0 >> "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

sleep 3
echo "=== [liuyao] serving on :8080, pid $(cat $PID_FILE) ==="
cat "$LOG_FILE"
"""

# ---------------------------------------------------------------
# 停止脚本
# 关键点：不得出现 exit（否则会中断整个部署进程）
# ---------------------------------------------------------------
STOP = """#!/bin/bash
PID_FILE=/root/app.pid
APP_DIR=/root/liuyao-divination

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID"
        sleep 3
        kill -0 "$PID" 2>/dev/null && kill -9 "$PID"
    fi
    rm -f "$PID_FILE"
fi

# 清理项目目录（带硬防护，防止误删根目录）
if [ -n "$APP_DIR" ] && [ "${#APP_DIR}" -gt 6 ] && [[ "$APP_DIR" == /root/* ]] && [ -d "$APP_DIR" ]; then
    rm -rf "$APP_DIR"
fi
# 注意：此处不得添加 exit
"""


def main():
    if not os.path.exists(CONFIG):
        print(f"❌ 找不到 {CONFIG}")
        print("   请先跑： aliyun appmanager init --non-interactive --name liuyao-divination \\")
        print("              --type app --ecs existing --instance-id i-f8z4nozc5klw0izmrtq7 \\")
        print("              --region cn-beijing --port 8080")
        sys.exit(1)

    with open(CONFIG, "r", encoding="utf-8") as f:
        config = yaml.safe_load(f) or {}

    config.setdefault("common", {})
    # 必须写在 common.scripts 下，顶层 scripts 会被忽略
    config["common"]["scripts"] = {"start": START, "stop": STOP}

    # 备份原配置
    bak = CONFIG + ".bak"
    if not os.path.exists(bak):
        with open(bak, "w", encoding="utf-8") as f:
            yaml.dump(yaml.safe_load(open(CONFIG, encoding="utf-8")), f,
                      default_flow_style=False, allow_unicode=True)

    with open(CONFIG, "w", encoding="utf-8") as f:
        yaml.dump(config, f, default_flow_style=False, allow_unicode=True)

    print(f"✅ 启停脚本已写入 {CONFIG}")
    print(f"   （原配置备份在 {bak}）")
    print()
    print("   校验一下写入位置对不对：")
    check_cmd = (
        "python3 -c \"import yaml;c=yaml.safe_load(open('%s'));"
        "s=c['common'].get('scripts',{});"
        "print('common.scripts.start 存在:', 'start' in s);"
        "print('common.scripts.stop  存在:', 'stop' in s)\"" % CONFIG
    )
    print("   " + check_cmd)
    print()
    print("   确认无误后继续跑询价和部署。")


if __name__ == "__main__":
    main()
