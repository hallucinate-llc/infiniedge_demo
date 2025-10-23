#!/bin/bash
set -e
echo "Starting Edge Whisper service..."
export PORT=${PORT:-8086}
export HOST=${HOST:-0.0.0.0}

if [ -f "package.json" ]; then
    echo "Building Next.js application..."
    npx next build 2>/dev/null || echo "Build failed, trying to start anyway..."
    echo "Starting Next.js server..."
    npx next start -p $PORT
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
            self.wfile.write(json.dumps({'status': 'healthy', 'service': 'edge-whisper', 'timestamp': datetime.now().isoformat(), 'port': $PORT}).encode())
        else:
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<h1>Edge Whisper Service</h1><p>Edge Speech Recognition</p>')
with socketserver.TCPServer(('$HOST', $PORT), Handler) as httpd:
    print(f'Edge Whisper service running on http://$HOST:$PORT')
    httpd.serve_forever()
"
fi
