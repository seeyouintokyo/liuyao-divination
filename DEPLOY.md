# 六爻起卦 — 阿里云 ECS 部署记录

> 已完成部署。本文是**实际过程的记录**，包含踩到的坑。
> 访问地址：**http://8.155.12.31:8080/**

---

## 最终结果

| 项 | 值 |
|---|---|
| 访问地址 | http://8.155.12.31:8080/ |
| 实例 | `i-f8z4nozc5klw0izmrtq7` |
| **地域** | **`cn-heyuan`（华南3·河源）** |
| 公网 IP | 8.155.12.31 |
| 应用组 | `default-cn-heyuan` |
| 应用名 | `liuyao-divination` |
| 服务端口 | 8080 |
| 部署目录 | `/root/liuyao-divination/` |
| 日志 / PID | `/root/app.log` · `/root/app.pid` |
| 控制台 | https://computenest.console.aliyun.com/app/detail?tabKey=overview&appName=liuyao-divination&groupName=default-cn-heyuan |

---

## 完整命令序列

```bash
cd /Users/xingyang/Downloads/code/sumsara/01_通用算卦网站/liuyao-divination

export SKILL_DIR="$HOME/.codex/skills/alibabacloud-ecs-code-deploy"
export SESSION_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
export ALIBABA_CLOUD_USER_AGENT="AlibabaCloud-Agent-Skills/alibabacloud-ecs-code-deploy/${SESSION_ID}"

# 1. 环境预检
python3 "$SKILL_DIR/scripts/deploy_toolkit.py" check

# 2. 初始化（注意地域是 cn-heyuan）
aliyun appmanager init --non-interactive \
  --name liuyao-divination --type app \
  --ecs existing --instance-id i-f8z4nozc5klw0izmrtq7 \
  --region cn-heyuan --port 8080

# 3. 写入启停脚本（关键，不能跳）
python3 write_scripts.py

# 4. 部署
python3 "$SKILL_DIR/scripts/deploy_toolkit.py" deploy \
  --type app --name liuyao-divination --group default-cn-heyuan --region cn-heyuan

# 5. 验证
python3 "$SKILL_DIR/scripts/deploy_toolkit.py" verify \
  --type app --name liuyao-divination --group default-cn-heyuan --region cn-heyuan --wait 20
```

> **询价那步（`deploy_toolkit.py price`）跳过了。** 原因见下方坑 4。

---

## 踩到的五个坑

### 坑 1：地域填错，最后一步才炸

第一次用了 `--region cn-beijing`。前面 8 步全过（打包、上传 OSS 都成功），到第 9 步落到实例时报：

```
InvalidParameter: ECS instance i-f8z4nozc5klw0izmrtq7 does not exist in region cn-beijing
```

**实例实际在 `cn-heyuan`（华南3·河源）。**

教训：地域必须和实例真实所在地一致。不确定就先查：

```bash
aliyun ecs describe-instances --region <地域> --biz-region-id <地域> --profile oauth
```

### 坑 2：ECS 的 Python 是 3.6.8，不认 `--directory`

启动脚本原本写的是：

```bash
python3 -m http.server 8080 --bind 0.0.0.0 --directory "$APP_DIR"
```

报错：

```
server.py: error: unrecognized arguments: --directory /root/liuyao-divination
```

**`--directory` 参数是 Python 3.7 才加的**，这台机器是 3.6.8。

改成先 `cd` 再起：

```bash
cd "$APP_DIR"
nohup python3 -m http.server 8080 --bind 0.0.0.0 >> "$LOG_FILE" 2>&1 &
```

### 坑 3：端口冲突

重部署时旧进程还占着 8080：

```
OSError: [Errno 98] Address already in use
```

在启动脚本开头加清理：

```bash
[ -f "$PID_FILE" ] && kill "$(cat $PID_FILE)" 2>/dev/null || true
rm -f "$PID_FILE"
pkill -f "http.server 8080" 2>/dev/null || true
sleep 2
```

### 坑 4：appmanager 1.1.5 没有 `price` 命令

skill 的询价步骤调用 `aliyun appmanager price`，但当前版本根本没有这个子命令：

```
Error: No such command 'price'.
```

**这个坑值得记：如果是部署到已有 ECS，本来就没有新增实例费用，跳过询价影响不大。**

### 坑 5：安全组没开 8080

服务在机器上跑得好好的（`LISTEN 0.0.0.0:8080`），外面就是访问不到。

查安全组发现规则里只有 `3000/3001/22/80/443/20/21/3389/888/8888`，**没有 8080**。

补一条：

```bash
aliyun ecs authorize-security-group \
  --region cn-heyuan --biz-region-id cn-heyuan --profile oauth \
  --security-group-id sg-f8zbnk84qxx9vbec3f1g \
  --permissions '[{"IpProtocol":"tcp","PortRange":"8080/8080","SourceCidrIp":"0.0.0.0/0","Description":"liuyao-divination"}]'
```

---

## 启停脚本要点

写在 `.appmanager/config.yaml` 的 `common.scripts` 下（顶层 `scripts:` 会被忽略）。

**启动脚本必须做的：**

| 步骤 | 原因 |
|---|---|
| `unzip` 解压 | appmanager 只上传 zip，**不自动解压**，不解压就没项目目录 |
| 装 python3 | ECS 是裸机，运行时得自己装 |
| `pkill` 清端口 | 避免上次的进程占着端口 |
| `--bind 0.0.0.0` | 默认只监听 127.0.0.1，安全组开了也进不来 |
| 日志写 `/root/app.log` | verify 脚本硬编码读这个路径 |
| 结尾 `cat` 日志 | 给验证环节抓取启动结果 |

**停止脚本不能有 `exit`** —— 部署系统把 stop + start 拼成一条命令跑，`exit` 会让 start 永远执行不到。

---

## 排查命令

```bash
# 看服务在不在
aliyun ecs run-command --region cn-heyuan --biz-region-id cn-heyuan --profile oauth \
  --instance-id i-f8z4nozc5klw0izmrtq7 --type RunShellScript \
  --content-encoding Base64 \
  --command-content "$(printf 'ss -ltnp | grep 8080' | base64 | tr -d '\n')"

# 拿命令结果（用上一步返回的 InvokeId）
aliyun ecs describe-invocation-results --region cn-heyuan --biz-region-id cn-heyuan \
  --profile oauth --invoke-id <InvokeId>

# 看部署状态
aliyun appmanager app status --name liuyao-divination --group_name default-cn-heyuan --output json

# 删除部署
aliyun appmanager app delete --name liuyao-divination
```

> `run-command` 的参数是 `--command-content` + `--content-encoding Base64`，**不是 `--command`**。

---

## 复用部署（改代码后重新上线）

```bash
cd /Users/xingyang/Downloads/code/sumsara/01_通用算卦网站/liuyao-divination
export SKILL_DIR="$HOME/.codex/skills/alibabacloud-ecs-code-deploy"
export ALIBABA_CLOUD_USER_AGENT="AlibabaCloud-Agent-Skills/alibabacloud-ecs-code-deploy/$(uuidgen | tr '[:upper:]' '[:lower:]')"

# 只要 config.yaml 还在，就不用重跑 init
python3 "$SKILL_DIR/scripts/deploy_toolkit.py" deploy \
  --type app --name liuyao-divination --group default-cn-heyuan --region cn-heyuan
python3 "$SKILL_DIR/scripts/deploy_toolkit.py" verify \
  --type app --name liuyao-divination --group default-cn-heyuan --region cn-heyuan --wait 20
```

---

## 文件清单

| 文件 | 作用 |
|---|---|
| `index.html` | 站点本体（19 KB 单文件） |
| `README.md` | 开源仓库说明 |
| `LICENSE` | MIT |
| `write_scripts.py` | 把启停脚本写进 config.yaml |
| `deploy.sh` | 命令备份 |
| `DEPLOY.md` | 本文件 |
| `diag.sh` | 远程诊断脚本 |
