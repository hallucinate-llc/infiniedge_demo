#!/bin/bash

# HTTP Gateway Fallback Service
# Provides basic reverse proxy functionality when nginx fails

PORT=${PORT:-80}
HOST=${HOST:-0.0.0.0}

echo "Starting HTTP Gateway Fallback Service on $HOST:$PORT"

# Create a simple Python HTTP reverse proxy
python3 -c "
import http.server
import socketserver
import urllib.request
import urllib.parse
from urllib.error import URLError

class ProxyHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        try:
            # Route to appropriate backend services
            path = self.path
            backend_port = None
            
            if path.startswith('/aegis/'):
                backend_port = 8080
                path = path[6:]  # Remove /aegis prefix
            elif path.startswith('/yomo/'):
                backend_port = 8082
                path = path[5:]  # Remove /yomo prefix
            elif path.startswith('/shifu/'):
                backend_port = 8083
                path = path[6:]  # Remove /shifu prefix
            elif path.startswith('/health'):
                self.send_response(200)
                self.send_header('Content-type', 'text/plain')
                self.end_headers()
                self.wfile.write(b'HTTP Gateway Fallback - Healthy\n')
                return
            else:
                # Default dashboard
                self.send_response(200)
                self.send_header('Content-type', 'text/plain')
                self.end_headers()
                self.wfile.write(b'InfiniteEdge HTTP Gateway Fallback\nServices: /aegis/ /yomo/ /shifu/\n')
                return
            
            if backend_port:
                # Proxy request to backend
                backend_url = f'http://localhost:{backend_port}{path}'
                if self.path.find('?') != -1:
                    backend_url += '?' + self.path.split('?', 1)[1]
                
                try:
                    with urllib.request.urlopen(backend_url, timeout=10) as response:
                        self.send_response(response.status)
                        for header, value in response.headers.items():
                            if header.lower() not in ['connection', 'transfer-encoding']:
                                self.send_header(header, value)
                        self.end_headers()
                        self.wfile.write(response.read())
                except URLError:
                    self.send_response(502)
                    self.send_header('Content-type', 'text/plain')
                    self.end_headers()
                    self.wfile.write(f'Backend service on port {backend_port} unavailable\n'.encode())
            
        except Exception as e:
            self.send_response(500)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(f'Gateway Error: {str(e)}\n'.encode())

with socketserver.TCPServer(('$HOST', $PORT), ProxyHandler) as httpd:
    print(f'HTTP Gateway serving on port $PORT')
    httpd.serve_forever()
"