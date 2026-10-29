# -*- coding: utf-8 -*-
"""把 build/web 构建产物部署到 GitHub Pages（gh-pages 分支，orphan 提交）。

用法: python tools/deploy_web.py
前提: build/web 已由 Godot 标准版导出；gh CLI 已登录（gh auth token）。
说明: 本机 github.com 的 git 端点经常断连，故走 api.github.com 的 Git Data API。
"""
import base64
import gzip
import hashlib
import json
import os
import subprocess
import urllib.error
import urllib.request

REPO = "192aaa/stardew-like"
BUILD = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "build", "web")
FILES = [
    "index.html",
    "index.js",
    "index.wasm",
    "index.wasm.gz",
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


# GitHub Pages 不会对 .wasm 做 gzip，前端 web_shell 会改成拉取 index.wasm.gz 并流式解压，
# 这样首屏传输从 37.7MB 降到约 9.6MB；wasm 更新后这里自动重新压缩
def ensure_wasm_gz() -> None:
    wasm = os.path.join(BUILD, "index.wasm")
    gz = wasm + ".gz"
    if os.path.exists(gz) and os.path.getmtime(gz) >= os.path.getmtime(wasm):
        return
    print("compressing index.wasm -> index.wasm.gz ...", flush=True)
    with open(wasm, "rb") as src, gzip.open(gz, "wb", compresslevel=9) as dst:
        dst.write(src.read())
    print("  gz size %.1f MB" % (os.path.getsize(gz) / 1048576.0), flush=True)


ensure_wasm_gz()


def api(endpoint, payload=None, method="GET", timeout=600, retries=2):
    url = "https://api.github.com/repos/%s/%s" % (REPO, endpoint)
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    for attempt in range(retries + 1):
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Authorization", "Bearer " + TOKEN)
        req.add_header("Accept", "application/vnd.github+json")
        req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                body = r.read().decode("utf-8")
                return json.loads(body) if body else {}
        except urllib.error.HTTPError as e:
            # 大文件 blob 上传偶发 502/504，重试一次通常就好
            if attempt < retries and e.code in (502, 503, 504):
                print("  retry %s (%d) ..." % (endpoint, e.code), flush=True)
                continue
            raise


def git_blob_sha(raw: bytes) -> str:
    """Git 对象 SHA1：sha1("blob <len>\\0" + content)，用于判断远端是否已有同内容文件"""
    return hashlib.sha1(b"blob %d\0" % len(raw) + raw).hexdigest()


# 先取现有 gh-pages 树的 sha，内容未变的文件（主要是 37.7MB 的 index.wasm）直接复用，
# 避免每次部署都重新上传大文件（GitHub 偶尔会在超大 blob 上返回 502）
remote = {}
try:
    old = api("git/trees/gh-pages?recursive=1")
    for item in old.get("tree", []):
        if item.get("type") == "blob":
            remote[item["path"]] = item["sha"]
except urllib.error.HTTPError as e:
    if e.code != 404:
        raise

tree = []
for f in FILES:
    path = os.path.join(BUILD, f)
    with open(path, "rb") as fh:
        raw = fh.read()
    sha = git_blob_sha(raw)
    if remote.get(f) == sha:
        print("reuse    %-32s (%.1f MB)" % (f, len(raw) / 1048576.0), flush=True)
    else:
        print("uploading %-32s (%.1f MB) ..." % (f, len(raw) / 1048576.0), flush=True)
        blob = api("git/blobs", {"content": base64.b64encode(raw).decode(), "encoding": "base64"}, "POST")
        sha = blob["sha"]
    tree.append({"path": f, "mode": "100644", "type": "blob", "sha": sha})

t = api("git/trees", {"tree": tree}, "POST")
print("tree ->", t["sha"], flush=True)
c = api("git/commits", {"message": MSG, "tree": t["sha"], "parents": []}, "POST")
print("commit ->", c["sha"], flush=True)
r = api("git/refs/heads/gh-pages", {"sha": c["sha"], "force": True}, "PATCH")
print("gh-pages ->", r["object"]["sha"])
print("部署完成，等待 Pages 构建后即可访问 https://192aaa.github.io/stardew-like/")
