# -*- coding: utf-8 -*-
"""把 build/web 构建产物部署到 GitHub Pages（gh-pages 分支，orphan 提交）。

用法: python tools/deploy_web.py
前提: build/web 已由 Godot 标准版导出；gh CLI 已登录（gh auth token）。
说明: 本机 github.com 的 git 端点经常断连，故走 api.github.com 的 Git Data API。
"""
import base64
import json
import os
import subprocess
import urllib.request

REPO = "192aaa/stardew-like"
BUILD = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "build", "web")
FILES = [
    "index.html",
    "index.js",
    "index.wasm",
    "index.pck",
    "index.audio.worklet.js",
    "index.audio.position.worklet.js",
    "index.png",
    "index.icon.png",
    "index.apple-touch-icon.png",
]
MSG = "Web 构建更新"

TOKEN = subprocess.run(["gh", "auth", "token"], capture_output=True, text=True).stdout.strip()
assert TOKEN, "需要先 gh auth login"


def api(endpoint, payload=None, method="GET", timeout=600):
    url = "https://api.github.com/repos/%s/%s" % (REPO, endpoint)
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", "Bearer " + TOKEN)
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=timeout) as r:
        body = r.read().decode("utf-8")
        return json.loads(body) if body else {}


tree = []
for f in FILES:
    path = os.path.join(BUILD, f)
    with open(path, "rb") as fh:
        raw = fh.read()
    print("uploading %-32s (%.1f MB) ..." % (f, len(raw) / 1048576.0), flush=True)
    blob = api("git/blobs", {"content": base64.b64encode(raw).decode(), "encoding": "base64"}, "POST")
    tree.append({"path": f, "mode": "100644", "type": "blob", "sha": blob["sha"]})

t = api("git/trees", {"tree": tree}, "POST")
print("tree ->", t["sha"], flush=True)
c = api("git/commits", {"message": MSG, "tree": t["sha"], "parents": []}, "POST")
print("commit ->", c["sha"], flush=True)
r = api("git/refs/heads/gh-pages", {"sha": c["sha"], "force": True}, "PATCH")
print("gh-pages ->", r["object"]["sha"])
print("部署完成，等待 Pages 构建后即可访问 https://192aaa.github.io/stardew-like/")
