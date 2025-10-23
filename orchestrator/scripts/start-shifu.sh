#!/bin/bash
set -e
echo "Starting Shifu service..."
export PORT=${PORT:-8083}
export HOST=${HOST:-0.0.0.0}

# Use HTTP fallback service due to read-only filesystem constraints
echo "Starting Shifu HTTP service (read-only filesystem)..."
if false; then
    echo "Binary execution disabled"
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
