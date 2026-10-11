#!/bin/bash
echo "=== 监听端口 (80/443/3000/8080) ==="
(ss -ltnp 2>/dev/null || netstat -tlnp 2>/dev/null) | grep -E ':(80|443|3000|8080) ' || echo "none"
echo "=== NGINX 是否安装 ==="
command -v nginx && nginx -v 2>&1 || echo "nginx-not-installed"
echo "=== NGINX 配置目录 ==="
ls -la /etc/nginx/conf.d/ 2>/dev/null || echo "no-conf.d"
ls -la /etc/nginx/sites-enabled/ 2>/dev/null || echo "no-sites-enabled"
echo "=== NGINX server_name 配置 ==="
grep -rh "server_name" /etc/nginx/ 2>/dev/null | grep -v "^\s*#" | head -15 || echo "none"
echo "=== 证书文件 ==="
find /etc/nginx /etc/ssl /root -maxdepth 3 -name "*.pem" -o -maxdepth 3 -name "*.crt" 2>/dev/null | head -10 || echo "none"
echo "=== Caddy/Apache ==="
command -v caddy https 2>/dev/null || command -v httpd apache2 2>/dev/null || echo "none"
echo "=== 已有站点目录 ==="
ls -la /root/ 2>/dev/null | head -15
echo "=== 8080 服务状态 ==="
curl -s -m 5 -o /dev/null -w "liuyao_local_http=%%{http_code}\n" http://127.0.0.1:8080/
