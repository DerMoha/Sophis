"""Local event relay for the two installed partner integration tests.

No Firebase credentials or diary payloads pass through this relay. Run only on
this development machine, then start both tests with matching run/port defines.
"""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from threading import Lock

EVENTS = {}
LOCK = Lock()


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        with LOCK:
            value = EVENTS.get(self.path)
        self.send_response(200 if value is not None else 404)
        self.end_headers()
        self.wfile.write(json.dumps(value).encode())

    def do_POST(self):
        size = int(self.headers.get('Content-Length', '0'))
        if size > 8192:
            self.send_error(413)
            return
        value = json.loads(self.rfile.read(size))
        with LOCK:
            EVENTS[self.path] = value
        print('event:', self.path, flush=True)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'{}')

    def log_message(self, *_):
        pass


if __name__ == '__main__':
    # Android's 10.0.2.2 alias reaches the host loopback interface.
    print('Partner test relay on 127.0.0.1:18765', flush=True)
    ThreadingHTTPServer(('127.0.0.1', 18765), Handler).serve_forever()
