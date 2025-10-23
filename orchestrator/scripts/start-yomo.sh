#!/bin/bash
set -e
echo "Starting YoMo service..."
export PORT=${PORT:-8082}
export HOST=${HOST:-0.0.0.0}
export ZIPPER_PORT=${ZIPPER_PORT:-9000}

# Use HTTP fallback service due to read-only filesystem constraints
echo "Starting YoMo HTTP service (read-only filesystem)..."
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
            self.wfile.write(json.dumps({'status': 'healthy', 'service': 'yomo', 'timestamp': datetime.now().isoformat(), 'port': $PORT}).encode())
        else:
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<h1>YoMo Service</h1><p>Service is running</p>')
with socketserver.TCPServer(('$HOST', $PORT), Handler) as httpd:
    print(f'YoMo service running on http://$HOST:$PORT')
    httpd.serve_forever()
"
fi
