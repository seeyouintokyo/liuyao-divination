#!/bin/bash
DOMAIN="liuyao.staraiwork.cn"
ROOT="/www/wwwroot/$DOMAIN"

echo "=== 1. 从 appmanager 部署目录复制站点文件 ==="
if [ -f /root/liuyao-divination/index.html ]; then
    cp -f /root/liuyao-divination/index.html "$ROOT/index.html"
    echo "已复制 index.html"
else
    echo "ERROR: /root/liuyao-divination/index.html 不存在"
fi
# 顺带把 README/LICENSE 也放过去（可选）
[ -f /root/liuyao-divination/README.md ] && cp -f /root/liuyao-divination/README.md "$ROOT/" 2>/dev/null
[ -f /root/liuyao-divination/LICENSE ] && cp -f /root/liuyao-divination/LICENSE "$ROOT/" 2>/dev/null

chown -R www:www "$ROOT"
echo "目录内容："
ls -la "$ROOT"

echo ""
echo "=== 2. 本地验证文件可访问 ==="
curl -s -m 8 -o /dev/null -w "local_http=%{http_code}\n" -H "Host: $DOMAIN" http://127.0.0.1/

echo ""
echo "=== 3. 从公网验证 DNS + HTTP 可达（certbot 前置检查）==="
curl -s -m 10 -o /dev/null -w "public_http=%{http_code}\n" http://$DOMAIN/ || echo "public http failed"

echo ""
echo "=== 4. 用 certbot 签发 Let's Encrypt 证书 ==="
certbot certonly --webroot -w "$ROOT" -d "$DOMAIN" \
  --non-interactive --agree-tos --keep-until-expiring 2>&1 | tail -20

echo ""
echo "=== 5. 证书是否生成 ==="
ls -la /etc/letsencrypt/live/$DOMAIN/ 2>/dev/null || echo "证书目录不存在"
