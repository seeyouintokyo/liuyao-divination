#!/bin/bash
echo "=== nginx.conf 主文件 ==="
cat /etc/nginx/nginx.conf 2>/dev/null | grep -vE "^\s*#" | grep -v "^\s*$"
echo ""
echo "=== include 的配置 ==="
grep -rh "include" /etc/nginx/nginx.conf 2>/dev/null
echo ""
echo "=== 所有包含 server 块的配置文件 ==="
grep -rl "server\s*{" /etc/nginx/ 2>/dev/null
echo ""
echo "=== 各配置文件的 server_name / root / listen ==="
grep -rn "server_name\|root \|listen\|proxy_pass" /etc/nginx/ 2>/dev/null | grep -v "^\s*#" | head -40
