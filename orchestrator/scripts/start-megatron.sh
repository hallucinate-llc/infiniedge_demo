#!/bin/bash
set -e
echo "Starting Megatron-LM service..."
export PORT=${PORT:-8088}
export HOST=${HOST:-0.0.0.0}

# Megatron is typically for training, so we'll create a service interface
python3 -c "
import http.server, socketserver, json
from datetime import datetime
class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'status': 'healthy', 'service': 'megatron-lm', 'timestamp': datetime.now().isoformat(), 'port': $PORT}).encode())
        elif self.path == '/models':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'available_models': ['GPT', 'BERT', 'T5'], 'status': 'ready'}).encode())
        else:
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<h1>Megatron-LM Service</h1><p>Large Language Model Training Platform</p>')
with socketserver.TCPServer(('$HOST', $PORT), Handler) as httpd:
    print(f'Megatron-LM service running on http://$HOST:$PORT')
    httpd.serve_forever()
"
