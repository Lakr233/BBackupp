#!/usr/bin/env python3

from http.server import BaseHTTPRequestHandler, HTTPServer

# log every request

class Worker(BaseHTTPRequestHandler):
    def do_GET(self):
        print(self.requestline)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'Hello, world!')
    
    def do_POST(self):
        print(self.requestline)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'Hello, world!')

if __name__ == '__main__':
    server = HTTPServer(('', 5555), Worker)
    server.serve_forever()

