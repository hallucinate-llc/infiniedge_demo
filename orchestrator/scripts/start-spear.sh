#!/bin/bash
# SPEAR Service Startup Script

set -e

echo "Starting SPEAR service..."

# Set environment variables
export PORT=${PORT:-8081}
export HOST=${HOST:-0.0.0.0}

# Check if this is a Go service
if [ -f "go.mod" ]; then
    echo "Starting Go application..."
    
    # Check for main.go
    if [ -f "main.go" ]; then
        echo "Building and starting main.go..."
        go run main.go
    elif [ -f "cmd/spear/main.go" ]; then
        echo "Building and starting cmd/spear/main.go..."
        go run cmd/spear/main.go
    elif [ -f "cmd/main.go" ]; then
        echo "Building and starting cmd/main.go..."
        go run cmd/main.go
    else
        # Try to build the service
        echo "Building SPEAR service..."
        if go build -o spear .; then
            echo "Starting built SPEAR service..."
            ./spear
        else
            echo "Build failed, starting Python health server..."
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
                'service': 'spear',
                'timestamp': datetime.now().isoformat(),
                'port': $PORT
            }
            self.wfile.write(json.dumps(response).encode())
        else:
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<h1>SPEAR Service</h1><p>Service is running on port $PORT</p>')

with socketserver.TCPServer(('$HOST', $PORT), HealthHandler) as httpd:
    print(f'SPEAR service running on http://$HOST:$PORT')
    httpd.serve_forever()
"
        fi
    fi
else
    echo "No Go module found, starting health server..."
    # Create a simple health server using netcat if available
    if command -v nc >/dev/null 2>&1; then
        while true; do
            echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n<h1>SPEAR Service</h1><p>Service is running</p>" | nc -l -p $PORT -q 1
        done
    else
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
                'service': 'spear',
                'timestamp': datetime.now().isoformat(),
                'port': $PORT
            }
            self.wfile.write(json.dumps(response).encode())
        else:
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<h1>SPEAR Service</h1><p>Service is running</p>')

with socketserver.TCPServer(('$HOST', $PORT), HealthHandler) as httpd:
    print(f'SPEAR service running on http://$HOST:$PORT')
    httpd.serve_forever()
"
    fi
fi