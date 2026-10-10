#!/usr/bin/env python3
import http.server
import json
import os
import posixpath
import time
from pathlib import Path
from urllib.parse import unquote

PORT = 8080
OLLAMA_DIR = os.path.expanduser("~/.ollama/models")
BLOBS_DIR = os.path.join(OLLAMA_DIR, "blobs")
MANIFESTS_DIR = os.path.join(OLLAMA_DIR, "manifests")
SERVE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def find_model_for_blob(blob_sha):
    raw_sha = blob_sha.replace('sha256-', '')
    short_sha = raw_sha[:12]
    try:
        for registry in os.listdir(MANIFESTS_DIR):
            reg_path = os.path.join(MANIFESTS_DIR, registry)
            if not os.path.isdir(reg_path): continue
            for model in os.listdir(reg_path):
                model_path = os.path.join(reg_path, model)
                for tag_file in Path(model_path).rglob('*'):
                    if tag_file.is_file():
                        try:
                            data = json.loads(tag_file.read_text())
                            for layer in data.get('layers', []):
                                if blob_sha in layer.get('digest', ''):
                                    return f"{registry}/{model}"
                        except: pass
    except: pass

    try:
        import re
        import urllib.parse
        log_path = os.path.expanduser("~/.ollama/logs/server.log")
        if os.path.exists(log_path):
            with open(log_path, 'r') as f:
                lines = f.readlines()[-5000:]
            for line in reversed(lines):
                if short_sha in line:
                    decoded = urllib.parse.unquote(line)
                    m = re.search(r"filename\*?=(?:UTF-8'')?([^&?\s;]+\.gguf)", decoded)
                    if m: return m.group(1).replace('+', ' ')
                    m = re.search(r'filename="([^"]+\.gguf)"', decoded)
                    if m: return m.group(1)
    except: pass

    return None

class OllamaHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=SERVE_DIR, **kwargs)
    
    def do_GET(self):
        # never serve the git directory (repo now lives in SERVE_DIR)
        p = posixpath.normpath(unquote(self.path.split('?')[0]))
        if p.strip('/').split('/', 1)[0] == '.git':
            self.send_error(404)
            return
        if self.path == '/api/check-downloads':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            partials = []
            try:
                if os.path.exists(BLOBS_DIR):
                    for f in os.listdir(BLOBS_DIR):
                        if '-partial' in f and '-partial-' not in f:
                            fpath = os.path.join(BLOBS_DIR, f)
                            size = os.path.getsize(fpath)
                            mtime = os.path.getmtime(fpath)
                            age = time.time() - mtime
                            blob_sha = f.replace('-partial', '')
                            model = find_model_for_blob(blob_sha)
                            partials.append({
                                "file": f,
                                "partial": f,
                                "size": size,
                                "modified": mtime,
                                "age_seconds": round(age),
                                "active": True,
                                "model": model
                            })
            except Exception as e:
                partials = [{"error": str(e)}]
            
            self.wfile.write(json.dumps({"partials": partials, "count": len(partials)}).encode())
        else:
            super().do_GET()
    
    def do_DELETE(self):
        if self.path.startswith('/api/delete-partial/'):
            self.send_header('Access-Control-Allow-Origin', '*')
            partial_name = self.path.split('/api/delete-partial/')[1]
            import urllib.parse
            partial_name = urllib.parse.unquote(partial_name)
            
            if not partial_name or '..' in partial_name or '/' in partial_name:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(json.dumps({"error": "invalid name"}).encode())
                return
            
            fpath = os.path.join(BLOBS_DIR, partial_name)
            shards_dir = BLOBS_DIR
            
            try:
                deleted = []
                if os.path.exists(fpath):
                    os.remove(fpath)
                    deleted.append(partial_name)
                
                base = partial_name.replace('-partial', '')
                for f in os.listdir(shards_dir):
                    if f.startswith(base + '-partial-'):
                        os.remove(os.path.join(shards_dir, f))
                        deleted.append(f)
                
                self.send_response(200)
                self.end_headers()
                self.wfile.write(json.dumps({"deleted": deleted}).encode())
            except Exception as e:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(json.dumps({"error": str(e)}).encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()

if __name__ == '__main__':
    with http.server.HTTPServer(('', PORT), OllamaHandler) as httpd:
        print(f"Server running at http://localhost:{PORT}")
        httpd.serve_forever()
