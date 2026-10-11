#!/bin/bash
DOMAIN="liuyao.staraiwork.cn"
NGX_CONF="/www/server/panel/vhost/nginx/$DOMAIN.conf"

echo "=== 1. 备份现有配置 ==="
cp -f "$NGX_CONF" "$NGX_CONF.bak"

echo "=== 2. 写入带 SSL 的配置 ==="
cat > "$NGX_CONF" <<'NGINXEOF'
server
{
    listen 80;
    listen 443 ssl http2;
    server_name liuyao.staraiwork.cn;
    index index.html index.htm;
    root /www/wwwroot/liuyao.staraiwork.cn;

    #CERT-APPLY-CHECK--START
    # 用于SSL证书申请时的文件验证相关配置 -- 请勿删除
    include /www/server/panel/vhost/nginx/well-known/liuyao.staraiwork.cn.conf;
    #CERT-APPLY-CHECK--END

    #SSL-START
    ssl_certificate    /etc/letsencrypt/live/liuyao.staraiwork.cn/fullchain.pem;
    ssl_certificate_key    /etc/letsencrypt/live/liuyao.staraiwork.cn/privkey.pem;
    ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;
    ssl_ciphers EECDH+CHACHA20:EECDH+CHACHA20-draft:EECDH+AES128:RSA+AES128:EECDH+AES256:RSA+AES256:EECDH+3DES:RSA+3DES:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_tickets on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    add_header Strict-Transport-Security "max-age=31536000";
    error_page 497  https://$host$request_uri;
    #SSL-END

    access_log  /www/wwwlogs/liuyao.staraiwork.cn.log;
    error_log  /www/wwwlogs/liuyao.staraiwork.cn.error.log;
}
NGINXEOF

echo "已写入（备份在 $NGX_CONF.bak）"

echo ""
echo "=== 3. nginx 配置测试 ==="
nginx -t 2>&1

echo ""
echo "=== 4. 重载 ==="
nginx -s reload 2>&1 && echo "reload ok"

echo ""
echo "=== 5. HTTPS 本地测试 ==="
curl -sk -m 10 -o /dev/null -w "https_local=%{http_code}\n" -H "Host: $DOMAIN" https://127.0.0.1/

echo ""
echo "=== 6. 证书信息 ==="
echo | openssl s_client -connect 127.0.0.1:443 -servername "$DOMAIN" 2>/dev/null | openssl x509 -noout -subject -dates 2>/dev/null

echo ""
echo "=== 7. HTTP 自动跳转检查（应返回 200 或 301）==="
curl -s -m 10 -o /dev/null -w "http=%{http_code}\n" -H "Host: $DOMAIN" http://127.0.0.1/
