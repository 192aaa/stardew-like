# -*- coding: utf-8 -*-
"""把 Fusion Pixel 字体裁成项目实际用到的字符集，大幅减小 pck 体积。

用法：python tools/subset_font.py
- 自动扫描项目内 .gd/.tscn/.godot/.cfg/.html 文本，收集所有出现的字符
- 额外并入 GB2312 一级常用汉字（3755 字）与 ASCII/常用标点，避免以后加文案缺字
- 首次运行时把原字体备份到项目目录外的 font_backup/（备份不进 pck）
- 完成后请重新执行 godot --headless --import
"""
import os
import shutil
import sys

from fontTools import subset

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, "assets", "fonts", "fusion_pixel.ttf")
BACKUP_DIR = os.path.join(os.path.dirname(ROOT), "font_backup")
SCAN_EXT = {".gd", ".tscn", ".godot", ".cfg", ".html"}
SKIP_DIRS = {".godot", "build", "node_modules", "__pycache__"}


def iter_chars():
    chars = set()
    for base, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in files:
            if os.path.splitext(name)[1].lower() not in SCAN_EXT:
                continue
            path = os.path.join(base, name)
            try:
                with open(path, "r", encoding="utf-8") as f:
                    chars.update(f.read())
            except (UnicodeDecodeError, OSError):
                pass
    return chars


def gb2312_level1():
    """GB2312 一级汉字（区 16-55），共 3755 字，覆盖绝大多数日常文案。"""
    chars = set()
    for hi in range(0xB0, 0xD8):
        for lo in range(0xA1, 0xFF):
            try:
                chars.add(bytes([hi, lo]).decode("gb2312"))
            except UnicodeDecodeError:
                continue
    return chars


def main():
    if not os.path.exists(FONT):
        print("找不到字体文件: %s" % FONT)
        return 1
    if not os.path.exists(BACKUP_DIR):
        os.makedirs(BACKUP_DIR)
    backup = os.path.join(BACKUP_DIR, "fusion_pixel_full.ttf")
    if not os.path.exists(backup):
        shutil.copy2(FONT, backup)
        print("已备份原字体 -> %s" % backup)

    chars = iter_chars()
    chars.update(chr(c) for c in range(0x20, 0x7F))
    chars.update("　、。〃々〈〉《》「」『』【】〔〕・…—～！＂＃＄％＆＇（）＊＋，－．／：；＜＝＞？＠［］＼＾＿｀｛｜｝￥·×÷√°※→←↑↓★☆○●◆◇■□▲△▼▽※")
    chars.update(gb2312_level1())
    chars = {c for c in chars if c.isprintable() or c == " "}
    text = "".join(sorted(chars))
    text_file = os.path.join(BACKUP_DIR, "charset.txt")
    with open(text_file, "w", encoding="utf-8") as f:
        f.write(text)

    before = os.path.getsize(FONT)
    subset.main([
        FONT,
        "--text-file=%s" % text_file,
        "--output-file=%s" % FONT,
        "--no-hinting",
        "--desubroutinize",
        "--layout-features=*",
        "--name-IDs=*",
        "--drop-tables+=DSIG",
    ])
    after = os.path.getsize(FONT)
    print("字符数 %d，字体 %d KB -> %d KB" % (len(chars), before // 1024, after // 1024))
    return 0


if __name__ == "__main__":
    sys.exit(main())
