#!/bin/bash
set -e
echo "Starting Whisper Finetune service..."
export PORT=${PORT:-8087}
export HOST=${HOST:-0.0.0.0}

if [ -f "app.py" ]; then
    python3 app.py
elif [ -f "train.py" ]; then
    echo "Starting training server..."
    python3 -c "
import http.server, socketserver, json
from datetime import datetime
class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'status': 'healthy', 'service': 'whisper-finetune', 'timestamp': datetime.now().isoformat(), 'port': $PORT}).encode())
        elif self.path == '/train':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'status': 'training ready', 'message': 'Submit training job'}).encode())
        else:
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<h1>Whisper Finetune Service</h1><p>Model Fine-tuning Platform</p>')
with socketserver.TCPServer(('$HOST', $PORT), Handler) as httpd:
    print(f'Whisper Finetune service running on http://$HOST:$PORT')
    httpd.serve_forever()
"
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
            self.wfile.write(json.dumps({'status': 'healthy', 'service': 'whisper-finetune', 'timestamp': datetime.now().isoformat(), 'port': $PORT}).encode())
        else:
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<h1>Whisper Finetune Service</h1><p>Model Fine-tuning Platform</p>')
with socketserver.TCPServer(('$HOST', $PORT), Handler) as httpd:
    print(f'Whisper Finetune service running on http://$HOST:$PORT')
    httpd.serve_forever()
"
fi
