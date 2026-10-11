#!/bin/bash
echo "=== PYVER ==="
python3 -V 2>&1
echo "=== LISTEN 8080 ==="
(ss -ltnp 2>/dev/null || netstat -tlnp 2>/dev/null) | grep 8080 || echo "no-listener-8080"
echo "=== HTTP.SERVER PROCS ==="
ps aux | grep "[h]ttp.server" || echo "no-http-server-proc"
echo "=== APPDIR ==="
ls -la /root/liuyao-divination/ 2>&1 | head -8
echo "=== PIDFILE ==="
cat /root/app.pid 2>&1
echo "=== APP.LOG (tail 20) ==="
tail -20 /root/app.log 2>&1
echo "=== LOCAL CURL TEST ==="
curl -s -m 5 -o /dev/null -w "local8080_http=%{http_code}\n" http://127.0.0.1:8080/ 2>&1
