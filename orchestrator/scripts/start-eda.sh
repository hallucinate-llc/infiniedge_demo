#!/bin/bash
set -e
echo "Starting EDA service..."
export PORT=${PORT:-8085}
export HOST=${HOST:-0.0.0.0}

if [ -f "app.py" ]; then
    python3 app.py
elif [ -f "main.py" ]; then
    python3 main.py
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
            self.wfile.write(json.dumps({'status': 'healthy', 'service': 'eda', 'timestamp': datetime.now().isoformat(), 'port': $PORT}).encode())
        else:
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<h1>EDA Service</h1><p>Event-Driven Architecture</p>')
with socketserver.TCPServer(('$HOST', $PORT), Handler) as httpd:
    print(f'EDA service running on http://$HOST:$PORT')
    httpd.serve_forever()
"
fi
