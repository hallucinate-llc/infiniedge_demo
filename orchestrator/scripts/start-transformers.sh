#!/bin/bash
set -e
echo "Starting Transformers service..."
export PORT=${PORT:-8089}
export HOST=${HOST:-0.0.0.0}

if [ -f "app.py" ]; then
    python3 app.py
elif [ -f "server.py" ]; then
    python3 server.py
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
            self.wfile.write(json.dumps({'status': 'healthy', 'service': 'transformers', 'timestamp': datetime.now().isoformat(), 'port': $PORT}).encode())
        elif self.path == '/models':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'models': ['BERT', 'GPT', 'RoBERTa', 'T5'], 'library': 'transformers'}).encode())
        else:
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<h1>Transformers Service</h1><p>Hugging Face Transformers Library</p>')
with socketserver.TCPServer(('$HOST', $PORT), Handler) as httpd:
    print(f'Transformers service running on http://$HOST:$PORT')
    httpd.serve_forever()
"
fi
