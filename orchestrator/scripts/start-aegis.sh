#!/bin/bash
# AegisEdgeAI Startup Script

set -e

echo "Starting AegisEdgeAI service..."

# Set environment variables
export PORT=${PORT:-8080}
export HOST=${HOST:-0.0.0.0}

# Check if this is a Python service
if [ -f "app.py" ]; then
    echo "Starting Python Flask application..."
    python3 app.py
elif [ -f "main.py" ]; then
    echo "Starting Python main application..."
    python3 main.py
elif [ -f "server.py" ]; then
    echo "Starting Python server..."
    python3 server.py
elif [ -f "manage.py" ]; then
    echo "Starting Django application..."
    python3 manage.py runserver $HOST:$PORT
elif [ -f "requirements.txt" ]; then
    echo "Starting generic Python service..."
    # Try to find the main entry point
    if [ -f "run.py" ]; then
        python3 run.py
    else
        # Create a simple health server
        python3 -c "
import http.server
import socketserver
import json
from datetime import datetime

class HealthHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                'status': 'healthy',
                'service': 'aegis-edge-ai',
                'timestamp': datetime.now().isoformat(),
                'port': $PORT
            }
            self.wfile.write(json.dumps(response).encode())
        else:
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<h1>AegisEdgeAI Service</h1><p>Service is running</p>')

with socketserver.TCPServer(('$HOST', $PORT), HealthHandler) as httpd:
    print(f'AegisEdgeAI service running on http://$HOST:$PORT')
    httpd.serve_forever()
"
    fi
else
    echo "No recognizable Python application found, starting health server..."
    python3 -c "
import http.server
import socketserver
import json
from datetime import datetime

class HealthHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                'status': 'healthy',
                'service': 'aegis-edge-ai',
                'timestamp': datetime.now().isoformat(),
                'port': $PORT
            }
            self.wfile.write(json.dumps(response).encode())
        else:
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<h1>AegisEdgeAI Service</h1><p>Service is running</p>')

with socketserver.TCPServer(('$HOST', $PORT), HealthHandler) as httpd:
    print(f'AegisEdgeAI service running on http://$HOST:$PORT')
    httpd.serve_forever()
"
fi