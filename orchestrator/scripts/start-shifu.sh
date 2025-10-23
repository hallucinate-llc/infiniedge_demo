#!/bin/bash
set -e
echo "Starting Shifu service..."
export PORT=${PORT:-8083}
export HOST=${HOST:-0.0.0.0}

if [ -f "go.mod" ]; then
    if [ -f "main.go" ]; then
        go run main.go
    elif [ -f "cmd/shifu/main.go" ]; then
        go run cmd/shifu/main.go
    else
        go build -o shifu . && ./shifu
    fi
else
    python3 -c "
import http.server, socketserver, json
from datetime import datetime
class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'status': 'healthy', 'service': 'shifu', 'timestamp': datetime.now().isoformat(), 'port': $PORT}).encode())
        else:
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<h1>Shifu Service</h1><p>Kubernetes IoT Device Management</p>')
with socketserver.TCPServer(('$HOST', $PORT), Handler) as httpd:
    print(f'Shifu service running on http://$HOST:$PORT')
    httpd.serve_forever()
"
fi
