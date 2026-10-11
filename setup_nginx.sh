#!/bin/bash
set -e
DOMAIN="liuyao.staraiwork.cn"
ROOT="/www/wwwroot/$DOMAIN"
NGX_CONF="/www/server/panel/vhost/nginx/$DOMAIN.conf"

echo "=== 1. 创建站点目录 ==="
mkdir -p "$ROOT"
chown -R www:www "$ROOT" 2>/dev/null || true
ls -la "$ROOT"

echo ""
echo "=== 2. 写入 nginx 配置（先 HTTP，用于签证书）==="
cat > "$NGX_CONF" <<'NGINXEOF'
server
{
    listen 80;
    server_name liuyao.staraiwork.cn;
    index index.html index.htm;
    root /www/wwwroot/liuyao.staraiwork.cn;

    #CERT-APPLY-CHECK--START
    include /www/server/panel/vhost/nginx/well-known/liuyao.staraiwork.cn.conf;
    #CERT-APPLY-CHECK--END

    access_log  /www/wwwlogs/liuyao.staraiwork.cn.log;
    error_log  /www/wwwlogs/liuyao.staraiwork.cn.error.log;
}
NGINXEOF

echo "已写入 $NGX_CONF"

echo ""
echo "=== 3. 建 well-known 目录（证书验证用）==="
mkdir -p /www/server/panel/vhost/nginx/well-known
cat > /www/server/panel/vhost/nginx/well-known/liuyao.staraiwork.cn.conf <<'WKEOF'
location ^~ /.well-known/acme-challenge/ {
    default_type "text/plain";
    root /www/wwwroot/liuyao.staraiwork.cn;
}
location = /.well-known/acme-challenge/ {
    return 404;
}
WKEOF
mkdir -p "$ROOT/.well-known/acme-challenge"
chown -R www:www "$ROOT/.well-known" 2>/dev/null || true

echo ""
echo "=== 4. nginx 配置测试 ==="
nginx -t 2>&1

echo ""
echo "=== 5. 重载 nginx ==="
nginx -s reload 2>&1 && echo "reload ok"

echo ""
echo "=== 6. DNS 解析确认 ==="
getent hosts liuyao.staraiwork.cn || echo "DNS 未生效（可能还在传播）"

echo ""
echo "=== 7. 本机 HTTP 测试 ==="
curl -s -m 8 -o /dev/null -w "http_local=%{http_code}\n" -H "Host: liuyao.staraiwork.cn" http://127.0.0.1/ || true
