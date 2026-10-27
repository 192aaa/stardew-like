# -*- coding: utf-8 -*-
"""通过 GitHub Git Data API 把当前工作区变更提交到 main（github.com git 端点不稳时的备用通道）。
用法：python tools/commit_main.py "提交信息"
流程：git status --porcelain 取变更文件 -> blob -> tree(base_tree=远端HEAD树) -> commit -> PATCH refs/heads/main
"""
import base64
import json
import os
import subprocess
import sys
import urllib.request

REPO = "192aaa/stardew-like"
API = "https://api.github.com"


def api(method, path, payload=None):
    token = subprocess.run(["gh", "auth", "token"], capture_output=True, text=True).stdout.strip()
    req = urllib.request.Request(API + path, method=method,
                                 data=json.dumps(payload).encode() if payload is not None else None)
    req.add_header("Authorization", "Bearer " + token)
    req.add_header("Accept", "application/vnd.github+json")
    with urllib.request.urlopen(req) as r:
        body = r.read()
    return json.loads(body) if body else {}


def main():
    msg = sys.argv[1] if len(sys.argv) > 1 else "update"
    root = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    out = subprocess.run(["git", "status", "--porcelain"], cwd=root, capture_output=True, text=True).stdout
    files = []
    for line in out.splitlines():
        st, path = line[:2], line[3:].strip().strip('"')
        if st.strip() in ("M", "A", "??") and not path.endswith("/"):
            files.append(path)
    if not files:
        print("没有变更文件")
        return

    head = api("GET", "/repos/%s/commits/main" % REPO)
    head_sha, base_tree = head["sha"], head["commit"]["tree"]["sha"]
    print("remote main HEAD:", head_sha)

    tree_items = []
    for p in files:
        with open(os.path.join(root, p), "rb") as f:
            data = f.read()
        blob = api("POST", "/repos/%s/git/blobs" % REPO,
                   {"content": base64.b64encode(data).decode(), "encoding": "base64"})
        tree_items.append({"path": p, "mode": "100644", "type": "blob", "sha": blob["sha"]})
        print("blob", p, len(data))

    tree = api("POST", "/repos/%s/git/trees" % REPO, {"base_tree": base_tree, "tree": tree_items})
    commit = api("POST", "/repos/%s/git/commits" % REPO, {
        "message": msg, "tree": tree["sha"], "parents": [head_sha]})
    api("PATCH", "/repos/%s/git/refs/heads/main" % REPO, {"sha": commit["sha"], "force": False})
    print("commit ->", commit["sha"])
    print("main ->", commit["sha"])


if __name__ == "__main__":
    main()
