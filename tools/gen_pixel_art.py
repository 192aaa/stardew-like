# -*- coding: utf-8 -*-
"""星露谷Like 像素资产生成器：程序化绘制全部 PNG，输出到 ../assets/（2x 最近邻放大）"""
import os
import random
from PIL import Image, ImageDraw

S = 2  # 像素放大倍数
OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets"))
os.makedirs(OUT, exist_ok=True)


def save(img, name):
    img.save(os.path.join(OUT, name))
    print("saved", name, img.size)


def grid(rows, pal):
    """字符画 -> RGBA 图，'.' 为透明"""
    h, w = len(rows), len(rows[0])
    for r in rows:
        assert len(r) == w, "行宽不一致: %d vs %d [%s]" % (len(r), w, r)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            c = pal.get(ch)
            if c:
                px[x, y] = c if len(c) == 4 else c + (255,)
    return img


def outline(img, col=(30, 26, 24, 255)):
    """给不透明像素加 1px 深色描边"""
    w, h = img.size
    src = img.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] > 0:
                dst[x, y] = src[x, y]
            else:
                near = False
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 0:
                        near = True
                        break
                if near:
                    dst[x, y] = col
    return out


def upscale(img):
    return img.resize((img.width * S, img.height * S), Image.NEAREST)


def shift_region(img, box, dy=1):
    """把 box 区域像素向下平移 dy（用于走路腿部动画帧）"""
    out = img.copy()
    px, spx = out.load(), img.load()
    x0, y0, x1, y1 = box
    for y in range(y1 - 1, y0 - 1, -1):
        for x in range(x0, x1):
            sy = y - dy
            px[x, y] = spx[x, sy] if sy >= y0 else (0, 0, 0, 0)
    return out


# ---------------- 地形贴图 ----------------

def tile_grass(seed=1, base=(96, 158, 74), dark=(78, 134, 58), light=(114, 176, 90), blade=(64, 116, 50), dots=False):
    rng = random.Random(seed)
    img = Image.new("RGBA", (16, 16))
    px = img.load()
    for y in range(16):
        for x in range(16):
            r = rng.random()
            c = dark if r < 0.16 else (light if r < 0.34 else base)
            px[x, y] = c + (255,)
    for _ in range(6):
        x, y = rng.randrange(16), rng.randrange(16)
        for dx, dy in ((0, 0), (1, 0), (0, -1)):
            px[(x + dx) % 16, (y + dy) % 16] = blade + (255,)
    if dots:  # 稀疏小花瓣点缀
        for _ in range(3):
            x, y = rng.randrange(16), rng.randrange(16)
            col = (244, 244, 236) if rng.random() < 0.5 else (246, 220, 120)
            px[x, y] = col + (255,)
            px[(x + 1) % 16, y] = col + (255,)
    return img


def tile_soil(wet=False):
    rng = random.Random(5 if not wet else 6)
    base = (88, 58, 38) if wet else (126, 88, 58)
    dark = (72, 47, 30) if wet else (106, 72, 46)
    spec = (64, 41, 26) if wet else (142, 102, 68)
    img = Image.new("RGBA", (16, 16))
    px = img.load()
    for y in range(16):
        for x in range(16):
            c = base
            if y % 4 == 3:
                c = dark
            r = rng.random()
            if r < 0.10:
                c = spec
            elif r < 0.16 and y % 4 != 3:
                c = dark
            px[x, y] = c + (255,)
    return img


def tile_water(frame=0):
    rng = random.Random(9)
    base, lite, deep = (64, 126, 190), (110, 166, 224), (52, 106, 168)
    img = Image.new("RGBA", (16, 16))
    px = img.load()
    for y in range(16):
        for x in range(16):
            r = rng.random()
            c = deep if r < 0.10 else (lite if r < 0.20 else base)
            px[x, y] = c + (255,)
    x0s = [2, 7, 12]
    for i, y in enumerate((3, 9, 14)):
        x0 = (x0s[i] + frame * 2) % 16
        for dx in range(4):
            px[(x0 + dx) % 16, (y + (dx % 2)) % 16] = lite + (255,)
    if frame % 2 == 1:  # 第二组波光交替出现
        for dx in range(3):
            px[(10 + dx) % 16, 6] = lite + (255,)
            px[(4 + dx) % 16, 12] = lite + (255,)
    return img


# ---------------- 玩家精灵表 ----------------

PAL_P = {
    "o": (44, 36, 30),    # 描边
    "h": (130, 90, 56),   # 头发亮
    "H": (96, 64, 40),    # 头发暗
    "s": (248, 208, 160), # 皮肤
    "e": (48, 40, 34),    # 眼睛
    "m": (206, 122, 100), # 嘴
    "w": (240, 236, 224), # 衬衫领
    "b": (74, 114, 186),  # 蓝夹克
    "B": (56, 88, 150),   # 夹克暗
    "p": (98, 74, 58),    # 裤子
    "P": (78, 58, 46),    # 裤子暗
    "k": (66, 48, 38),    # 靴子
}

BODY_DOWN = [
    "................",
    "....oooooooo....",
    "...ohhhhhhhho...",
    "..ohhhhhhhhhho..",
    "..ohHhhhhhhHho..",
    "..ohhhhhhhhhho..",
    "..ohhsssssshho..",
    "..ohsessssesho..",
    "..ohssssssssho..",
    "..ohsssmmsssho..",
    "...ohssssssho...",
    "....owwwwwwo....",
    "..obbbbbbbbbbo..",
    "..obbbbbbbbbbo..",
    "..obbbbbbbbbbo..",
    "..osbbbbbbbbso..",
    "..oBBBBBBBBBBo..",
    "...oppppppppo...",
    "...oPpppppppo...",
    "...opppoopppo...",
    "...okkkookkko...",
    "....oooooooo....",
]
BODY_UP = [
    "................",
    "....oooooooo....",
    "...ohhhhhhhho...",
    "..ohhhhhhhhhho..",
    "..ohHhhhhhhHho..",
    "..ohhhhhhhhhho..",
    "..ohhhhhhhhhho..",
    "..ohhhhhhhhhho..",
    "..ohhhhhhhhhho..",
    "..ohhhhhhhhhho..",
    "...ohhhhhhhho...",
    "....oBBBBBBo....",
    "..obbbbbbbbbbo..",
    "..obbbbbbbbbbo..",
    "..obbbbbbbbbbo..",
    "..osbbbbbbbbso..",
    "..oBBBBBBBBBBo..",
    "...oppppppppo...",
    "...oPpppppppo...",
    "...opppoopppo...",
    "...okkkookkko...",
    "....oooooooo....",
]
BODY_SIDE = [
    "................",
    "....oooooooo....",
    "...ohhhhhhhho...",
    "..ohhhhhhhhhho..",
    "..ohhhhhhhhhho..",
    "..ohhhhhhhhHho..",
    "..ohhhhhhsssso..",
    "..ohhhhhhsesso..",
    "..ohhhhhhsssso..",
    "..ohhhhhhssmso..",
    "...ohhsssssso...",
    "....owwwwwwo....",
    "..obbbbbbbbbbo..",
    "..obbbbbbbbbbo..",
    "..obbbbbbbbbbo..",
    "..obbbbbbbbbso..",
    "..oBBBBBBBBBBo..",
    "...oppppppppo...",
    "...oPpppppppo...",
    "...oppppppppo...",
    "...okkkkkkkko...",
    "....oooooooo....",
]


def player_sheet():
    frames = []  # 3 方向 x 3 帧（站/走A/走B）
    for body, legbox in ((BODY_DOWN, (3, 19, 8, 22)), (BODY_UP, (3, 19, 8, 22)), (BODY_SIDE, (3, 18, 13, 22))):
        base = grid(body, PAL_P)
        walkA = shift_region(base, legbox, 1)
        walkB = shift_region(base, (16 - legbox[2], legbox[1], 16 - legbox[0], legbox[3]), 1)
        frames += [base, walkA, walkB]
    # 表：4 列（站/走A/站/走B）x 3 行（下/上/侧）
    sheet = Image.new("RGBA", (16 * 4, 22 * 3), (0, 0, 0, 0))
    for d in range(3):
        st, wa, wb = frames[d * 3: d * 3 + 3]
        for c, fr in ((0, st), (1, wa), (3, wb)):
            sheet.paste(fr, (c * 16, d * 22))
    return upscale(outline_sheet(sheet, 16, 22))


def outline_sheet(img, fw, fh):
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    for ry in range(img.height // fh):
        for rx in range(img.width // fw):
            tile = img.crop((rx * fw, ry * fh, (rx + 1) * fw, (ry + 1) * fh))
            out.paste(outline(tile, (44, 36, 30, 255)), (rx * fw, ry * fh))
    return out


# ---------------- 作物图集 ----------------

PAL_C = {
    "o": (34, 48, 26), "g": (88, 150, 62), "G": (64, 118, 48),
    "y": (168, 190, 86), "w": (238, 226, 168),
    "d": (58, 108, 44), "t": (150, 108, 62), "T": (118, 82, 46),
}


def crop_parsnip(stage):
    if stage == 0:
        rows = [
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            ".......gg.......",
            "......g..g......",
            ".......gg.......",
            ".......og.......",
            ".......og.......",
            "......ogg.......",
            "................",
        ]
    elif stage == 1:
        rows = [
            "................",
            "................",
            "................",
            "................",
            "................",
            "......gg........",
            ".....gggg..gg...",
            "....gg.gg.gg....",
            ".....oogggg.....",
            "......ogg.......",
            "......ogg.......",
            "......ogg.......",
            "......oGg.......",
            ".....oGGg.......",
            "................",
            "................",
        ]
    elif stage == 2:
        rows = [
            "................",
            "................",
            "................",
            ".....gg...gg....",
            "....gggg.gg.....",
            "...gg.gggg.gg...",
            "...og.gggggg....",
            "....oogggo......",
            ".....ogggo......",
            ".....ogggg......",
            ".....ogGgg......",
            ".....ogGgg......",
            ".....oGGGg......",
            "....oGGGGg......",
            "................",
            "................",
        ]
    else:
        rows = [
            "................",
            "................",
            "....yy....yy....",
            "...yyyy.gyyy....",
            "..yy.gyyy.yy....",
            "..oy.yyyy.yy....",
            "...ooyyyyo......",
            "....oyyyyo......",
            ".....oyyo.......",
            ".....oyyo.......",
            "....oowwoo......",
            "....owwwwo......",
            "....owwwwo......",
            "...owwwwwwo.....",
            "...owwwwwwo.....",
            "................",
        ]
    return rows


def crop_potato(stage):
    if stage == 0:
        rows = [
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "......gg........",
            ".....gggg.......",
            "......gg........",
            ".....ogg........",
            ".....oGg........",
            "................",
            "................",
        ]
    elif stage == 1:
        rows = [
            "................",
            "................",
            "................",
            "................",
            "................",
            ".....gggg.......",
            "....gggggg.gg...",
            "...ggdggdggg....",
            "...odggggddo....",
            "....odggggdo....",
            ".....odggo......",
            ".....oGGo.......",
            ".....oGGo.......",
            "................",
            "................",
            "................",
        ]
    elif stage == 2:
        rows = [
            "................",
            "................",
            "................",
            "....gg...ggg....",
            "...gggg.gggg....",
            "..ggdgggggdgg...",
            "..odgggggggdo...",
            "...odgggggdo....",
            "....odgggdo.....",
            "....odgggdo.....",
            ".....oGGGo......",
            ".....oGGGo......",
            ".....oGGo.......",
            "................",
            "................",
            "................",
        ]
    else:
        rows = [
            "................",
            "................",
            "................",
            "....gg....gg....",
            "...gggg.gggg....",
            "..ggdgggggdgg...",
            "..odgggggggdo...",
            "...odgggggdo....",
            "....odgggdo.....",
            "....odgggdo.....",
            "..ttoGGGGot.....",
            ".tTTtoGGotTTo...",
            ".oTTToooTTTo....",
            "..oooo..oooo....",
            "................",
            "................",
        ]
    return rows


def crops_atlas():
    art = Image.new("RGBA", (16 * 8, 16), (0, 0, 0, 0))
    order = [crop_parsnip(0), crop_parsnip(1), crop_parsnip(2), crop_parsnip(3),
             crop_potato(0), crop_potato(1), crop_potato(2), crop_potato(3)]
    for i, rows in enumerate(order):
        art.paste(outline(grid(rows, PAL_C), (30, 42, 24, 255)), (i * 16, 0))
    return upscale(art)


# ---------------- 树 / 房屋 / 商店 ----------------

def tree():
    w, h = 32, 48
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    canopy = ((16, 20, 13), (10, 26, 9), (22, 26, 9))
    dark, mid, lite = (44, 92, 48), (66, 128, 58), (92, 158, 74)
    for cx, cy, r in canopy:
        for y in range(h):
            for x in range(w):
                d2 = (x - cx) ** 2 + (y - cy) ** 2
                if d2 <= r * r:
                    px[x, y] = dark + (255,)
    for cx, cy, r in canopy:
        for y in range(h):
            for x in range(w):
                d2 = (x - cx + 1) ** 2 + (y - cy + 1) ** 2
                if d2 <= (r - 2) ** 2 and px[x, y][3] > 0:
                    px[x, y] = mid + (255,)
    for y in range(h):
        for x in range(w):
            d2 = (x - 12) ** 2 + (y - 15) ** 2
            if d2 <= 16 and px[x, y][3] > 0:
                px[x, y] = lite + (255,)
    # 树干
    for y in range(33, 46):
        for x in range(13, 19):
            c = (110, 76, 46)
            if x in (13, 18):
                c = (84, 56, 34)
            if y in (33, 45):
                c = (70, 46, 28)
            px[x, y] = c + (255,)
    px[15, 36] = (84, 56, 34, 255)
    px[16, 40] = (84, 56, 34, 255)
    return upscale(outline(img, (36, 30, 24, 255)))


def house():
    w, h = 124, 92
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # 墙
    d.rectangle((8, 42, 115, 91), fill=(226, 206, 168, 255))
    for y in range(48, 91, 7):
        d.line((8, y, 115, y), fill=(206, 184, 146, 255))
    # 屋顶
    d.polygon([(2, 44), (62, 2), (121, 44)], fill=(168, 72, 60, 255))
    for y in range(6, 44, 5):
        x0 = 62 - (y - 2) * 60 // 42
        x1 = 62 + (y - 2) * 60 // 42
        d.line((max(x0, 2), y, min(x1, 121), y), fill=(140, 56, 48, 255))
    d.line((2, 44, 121, 44), fill=(120, 46, 40, 255))
    d.line((62, 2, 62, 44), fill=(140, 56, 48, 255))
    # 门
    d.rectangle((52, 58, 71, 91), fill=(120, 82, 48, 255))
    d.rectangle((52, 58, 71, 61), fill=(96, 64, 38, 255))
    d.rectangle((55, 64, 68, 88), fill=(140, 98, 58, 255))
    d.rectangle((66, 74, 68, 76), fill=(234, 198, 92, 255))
    # 窗
    d.rectangle((20, 54, 42, 72), fill=(150, 198, 226, 255))
    d.rectangle((20, 54, 42, 72), outline=(96, 68, 42, 255))
    d.line((31, 54, 31, 72), fill=(96, 68, 42, 255))
    d.line((20, 63, 42, 63), fill=(96, 68, 42, 255))
    d.line((18, 73, 44, 73), fill=(150, 110, 66, 255), width=2)
    # 烟囱
    d.rectangle((92, 12, 102, 34), fill=(150, 110, 100, 255))
    d.rectangle((92, 12, 102, 15), fill=(120, 84, 76, 255))
    return upscale(outline(img, (52, 40, 32, 255)))


def stall():
    w, h = 110, 60
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # 支柱
    d.rectangle((3, 8, 9, 47), fill=(126, 92, 56, 255))
    d.rectangle((100, 8, 106, 47), fill=(126, 92, 56, 255))
    # 雨棚条纹
    for i in range(8):
        c = (196, 70, 62, 255) if i % 2 == 0 else (238, 232, 220, 255)
        d.rectangle((2 + i * 13.5, 0, 2 + (i + 1) * 13.5, 14), fill=c)
    for i in range(8):
        x = 2 + i * 13.5
        c = (150, 48, 44, 255) if i % 2 == 0 else (206, 198, 184, 255)
        d.rectangle((x, 12, x + 13.5, 14), fill=c)
    # 柜台
    d.rectangle((2, 38, 107, 59), fill=(150, 108, 64, 255))
    d.rectangle((2, 38, 107, 42), fill=(176, 130, 78, 255))
    for y in range(46, 59, 5):
        d.line((2, y, 107, y), fill=(128, 90, 52, 255))
    # 种子袋
    d.rectangle((22, 26, 34, 39), fill=(222, 196, 120, 255))
    d.rectangle((24, 24, 32, 28), fill=(190, 164, 96, 255))
    d.rectangle((46, 26, 58, 39), fill=(188, 150, 196, 255))
    d.rectangle((48, 24, 56, 28), fill=(158, 122, 168, 255))
    return upscale(outline(img, (56, 42, 32, 255)))


def fence_post():
    img = grid([
        ".oooo.",
        "oHHHHo",
        "ohhhho",
        "ohhhho",
        "ohhhho",
        "ohhhho",
        "ohhhho",
        "ohhhho",
        "ohhhho",
        "ohhhho",
        "ohhhho",
        "oPppPo",
        ".oooo.",
        ".oooo.",
    ], {"o": (56, 40, 28), "h": (146, 106, 62), "H": (170, 128, 78), "p": (118, 84, 48), "P": (98, 70, 40)})
    return upscale(outline(img, (46, 34, 24, 255)))


def fence_rail():
    img = Image.new("RGBA", (16, 4), (0, 0, 0, 0))
    px = img.load()
    for x in range(16):
        for y in range(4):
            c = (146, 106, 62)
            if y == 0:
                c = (170, 128, 78)
            if y == 3:
                c = (110, 78, 46)
            px[x, y] = c + (255,)
    return upscale(outline(img, (46, 34, 24, 255)))


def flowers_atlas():
    cols = [((232, 120, 160), (250, 210, 226)), ((240, 238, 230), (252, 250, 244)),
            ((214, 72, 60), (240, 140, 120)), ((238, 196, 70), (248, 226, 140))]
    atlas = Image.new("RGBA", (8 * 4, 8), (0, 0, 0, 0))
    for i, (petal, lite) in enumerate(cols):
        img = grid([
            "........",
            "..pp....",
            ".pLLp...",
            ".pLLp...",
            "..pp....",
            "...s....",
            "...s....",
            "..ss....",
        ], {"p": petal, "L": lite, "s": (74, 122, 52)})
        atlas.paste(img, (i * 8, 0))
    return upscale(atlas)


def lily():
    img = grid([
        "...oooooo...",
        ".ooGGGGGGoo.",
        "oGGGGGGGGGGo",
        "oGGGGGGGGGGo",
        "oGGGGGGGGGGo",
        ".ooGGGGGGoo.",
        "...oooooo...",
    ], {"o": (52, 106, 60), "G": (86, 156, 88)})
    px = img.load()
    for dy in range(3):  # 缺口
        for dx in range(3 - dy):
            px[dx, 2 + dy] = (0, 0, 0, 0)
    px[7, 2] = (244, 160, 190, 255)
    px[8, 2] = (244, 160, 190, 255)
    px[7, 3] = (252, 200, 220, 255)
    return upscale(outline(img, (40, 84, 48, 255)))


def stone():
    img = grid([
        "..oooo..",
        ".oLLLLo.",
        "oLGGGGo.",
        "oGGGGGo.",
        ".oooooo.",
    ], {"o": (110, 104, 92), "L": (188, 182, 168), "G": (150, 144, 130)})
    return upscale(outline(img, (96, 90, 80, 255)))


def shadow():
    img = Image.new("RGBA", (28, 11), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((0, 0, 27, 10), fill=(20, 24, 16, 80))
    return upscale(img)


def sign():
    img = grid([
        "o" * 22,
        "ohhhhhhhhhhhhhhhhhhhho",
        "ohHHHHHHHHHHHHHHHHHHho",
        "ohhhhhhhhhhhhhhhhhhhho",
        "o" * 22,
    ] * 1, {"o": (56, 40, 28), "h": (150, 108, 64), "H": (176, 132, 82)})
    img = img.crop((0, 0, 22, 5))
    return upscale(img)


# ---------------- 画质增强资产 ----------------

def pond_edge(w=120, h=80):
    """池塘沙边框（中心透明）：沙环 + 深水描边 + 圆角"""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    rng = random.Random(11)
    sand, sand_d, rim = (224, 206, 158), (198, 178, 130), (38, 82, 128)
    for y in range(h):
        for x in range(w):
            if x < 5 or x >= w - 5 or y < 5 or y >= h - 5:
                c = sand_d if rng.random() < 0.25 else sand
                px[x, y] = c + (255,)
    for y in range(5, h - 5):
        for x in range(5, w - 5):
            if x < 7 or x >= w - 7 or y < 7 or y >= h - 7:
                px[x, y] = rim + (255,)
    for cx, cy in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):  # 圆角
        for dx in range(6):
            for dy in range(6 - dx):
                px[(cx + dx if cx == 0 else cx - dx, cy + dy if cy == 0 else cy - dy)] = (0, 0, 0, 0)
    return upscale(img)


def render_patch(w, h, seed):
    """预渲染农田地块：暗草底 + 深色描边 + 内侧高光 + 割草纹理"""
    rng = random.Random(seed)
    base, dark, light = (84, 146, 64), (58, 104, 44), (100, 162, 78)
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            r = rng.random()
            c = dark if r < 0.18 else (light if r < 0.32 else base)
            px[x, y] = c + (255,)
    for y in range(0, h, 12):  # 割草纹
        for x in range(w):
            if rng.random() < 0.5:
                px[x, (y + x // 3) % h] = (74, 128, 56, 255)
    for y in range(h):  # 描边 + 内高光
        for x in range(w):
            if x == 0 or y == 0 or x == w - 1 or y == h - 1:
                px[x, y] = (52, 94, 40, 255)
            elif x == 1 or y == 1 or x == w - 2 or y == h - 2:
                px[x, y] = (110, 172, 88, 255)
    return upscale(img)


def tuft():
    img = grid([
        "........",
        "..g.....",
        "..g..d..",
        ".gg..d..",
        ".gd.gd..",
        "..ddd...",
        "..ddd...",
        "........",
    ], {"g": (74, 130, 56), "d": (58, 106, 46)})
    return upscale(outline(img, (44, 84, 36, 255)))


def glow(size=32, col=(255, 214, 130)):
    """像素阶梯径向光晕"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    c = size / 2.0
    for y in range(size):
        for x in range(size):
            d = ((x - c + 0.5) ** 2 + (y - c + 0.5) ** 2) ** 0.5 / c
            if d < 1.0:
                a = max(0.0, 1.0 - d)
                a = int(a * 6) / 6.0  # 量化成阶梯
                px[x, y] = col + (int(210 * a),)
    return img.resize((size * S, size * S), Image.NEAREST)


def lamp():
    img = grid([
        "..oooo..",
        ".oHHHHo.",
        "oHyyyHe.",
        "oHyyyHo.",
        ".oHHHHo.",
        "..oooo..",
        "...oo...",
        "...oo...",
        "...oo...",
        "...oo...",
        "...oo...",
        "...oo...",
        "...oo...",
        "..oppo..",
        ".oppppo.",
        ".oooooo.",
    ], {"o": (54, 42, 32), "H": (96, 78, 58), "y": (252, 224, 140), "p": (110, 82, 52)})
    return upscale(outline(img, (40, 32, 24, 255)))


def pine():
    w, h = 32, 48
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(4, 36):  # 三角树冠
        half = max(1, (y - 4) * 13 // 30)
        for x in range(16 - half, 17 + half):
            c = (46, 96, 52)
            if x <= 16 - half + 2:
                c = (66, 122, 66)
            if y % 7 == 3:
                c = (38, 84, 46)
            px[x, y] = c + (255,)
    for y in range(34, 46):  # 树干
        for x in range(13, 19):
            px[x, y] = ((84, 56, 34) if x in (13, 18) else (110, 76, 46)) + (255,)
    return upscale(outline(img, (32, 44, 34, 255)))


def vignette(w=480, h=270):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    cx, cy = w / 2.0, h / 2.0
    maxd = (cx ** 2 + cy ** 2) ** 0.5
    for y in range(h):
        for x in range(w):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 / maxd
            t = max(0.0, (d - 0.62) / 0.38)
            a = int(min(1.0, t) ** 1.6 * 150 / 25) * 25  # 阶梯量化
            if a > 0:
                px[x, y] = (12, 10, 20, a)
    return img


# ---------------- 玩法扩展资产 ----------------

def boulder():
    """可敲碎的大石头"""
    img = grid([
        "................",
        "................",
        "....rrrrrrr.....",
        "...rrrrrrrrr....",
        "..rllrrrrrrrr...",
        ".rlllrrrrrrrrr..",
        ".rllrrrrrrddrr..",
        ".rlrrrrrrrddrr..",
        ".rrrrrrrrrddrr..",
        ".rrrrrrrrrrrrr..",
        ".rrrrrrrrrrrr...",
        "..rrrrrrrrrr....",
        "...ddddddddd....",
        "................",
        "................",
        "................",
    ], {"r": (146, 146, 154), "l": (176, 178, 186), "d": (104, 104, 114)})
    return upscale(outline(img, (58, 58, 66, 255)))


def branch():
    """地上的枯树枝"""
    img = grid([
        "................",
        "................",
        "................",
        "................",
        "...........bb...",
        "..........bllb..",
        ".........bllb...",
        "..b.....bllb....",
        "..bb...bllb.....",
        "...bb.bllb......",
        "....bbllb.......",
        ".....bbb........",
        "....BB.BB.......",
        "................",
        "................",
        "................",
    ], {"b": (128, 90, 54), "l": (152, 112, 68), "B": (100, 68, 40)})
    return upscale(outline(img, (58, 40, 26, 255)))


def scarecrow():
    """稻草人：草帽 + 麻袋头 + 旧外套 + 木杆"""
    rows = [
        "................",
        "................",
        ".....oooooo.....",
        "....ohhhhhho....",
        "..oooooooooooo..",
        "..ohhhhhhhhhho..",
        "...osssssssso...",
        "...osesssseso...",
        "...osssssssso...",
        "...ossmmmmsso...",
        "...osssssssso...",
        "....oooooooo....",
        "ohjjjjjjjjjjjjho",
        "ohjjjjjjjjjjjjho",
        ".....ojjjjo.....",
        ".....ojjjjo.....",
        ".....ojppjo.....",
        ".....ojjjjo.....",
        ".....ojjjjo.....",
    ]
    rows += [".....oppppo....."] * 10
    rows += [".....oooooo.....", "................", "................"]
    img = grid(rows, {
        "o": (58, 44, 30), "h": (216, 186, 104), "s": (206, 184, 142),
        "e": (60, 48, 36), "m": (120, 96, 66), "j": (124, 88, 60),
        "p": (168, 140, 88), "": None,
    })
    return upscale(outline(img, (50, 38, 26, 255)))


def sprinkler():
    """洒水器：金属喷头 + 底座"""
    img = grid([
        "................",
        "......ssss......",
        "......sggs......",
        "......sggs......",
        "...ssssssssss...",
        "...sggssssggs...",
        "...ssssssssss...",
        ".....ssssss.....",
        "....ssssssss....",
        "....sggggggs....",
        "....ssssssss....",
        "................",
        "................",
        "................",
        "................",
        "................",
    ], {"s": (168, 172, 182), "g": (108, 112, 124)})
    return upscale(outline(img, (66, 68, 78, 255)))


def fish_icon():
    """钓鱼小游戏里的鱼"""
    img = grid([
        "................",
        "................",
        "................",
        "....ffffff......",
        "..ffffffffff.f..",
        ".fffefffffffff..",
        ".fffffffffffff..",
        ".ffwwwwffffff.f.",
        "..ffwwffffff.f..",
        "....ffffff......",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
    ], {"f": (94, 162, 206), "w": (226, 238, 248), "e": (34, 44, 58)})
    return upscale(outline(img, (40, 70, 96, 255)))


def bobber():
    """鱼漂 8x8"""
    img = grid([
        "..rrrr..",
        ".rrrrrr.",
        ".rrwwrr.",
        ".wwwwww.",
        ".wwwwww.",
        ".dwwwwd.",
        "..dddd..",
        "........",
    ], {"r": (208, 62, 52), "w": (242, 238, 228), "d": (148, 42, 36)})
    return upscale(img)


def well():
    """村庄水井：木架坡顶 + 石圈 + 井口"""
    img = grid([
        "....oooooooooooooooo....",
        "...oHHHHHHHHHHHHHHHHo...",
        "..oHHHHhHHHHHHhHHHHHHo..",
        ".oHHHHHHHHHHHHHHHHHHHHo.",
        ".oRHHHHHHHHHHHHHHHHHHRo.",
        "..oooooooooooooooooooo..",
        "...op..............po...",
        "...op..............po...",
        "...op..............po...",
        "...op..............po...",
        "...op..............po...",
        "...op..............po...",
        "..ossssssssssssssssso...",
        ".osLLsssssssssssssssso..",
        ".osLLsssssssssssssssso..",
        ".osssssssssshhhhssssso..",
        ".ossssssssshhhhhhsssso..",
        ".ossssssssshhhhhhsssso..",
        "..osssssssssshhsssssso..",
        "..oooooooooooooooooooo..",
    ], {
        "o": (54, 40, 30), "H": (150, 96, 60), "h": (176, 120, 74), "R": (122, 74, 46),
        "p": (110, 76, 46), "s": (150, 146, 138), "L": (186, 182, 172),
    })
    return upscale(outline(img, (44, 34, 26, 255)))


def mailbox():
    """红色小信箱"""
    img = grid([
        "..........",
        ".oooooooo.",
        "oRRRRRRRRo",
        "oRrrrrrrRo",
        "oRRRRRRRRo",
        "oRRRRRyRRo",
        "oooooooooo",
        "...oppo...",
        "...oppo...",
        "...oppo...",
        "..oppppo..",
        "..oooooo..",
    ], {"o": (54, 40, 30), "R": (196, 84, 66), "r": (224, 128, 104),
        "y": (240, 210, 110), "p": (110, 76, 46)})
    return upscale(outline(img, (46, 34, 26, 255)))


def bush(berry):
    """野莓丛：满枝红莓 / 采摘后"""
    img = grid([
        "....................",
        "......gggg.ggg......",
        "....gggGGgggGGgg....",
        "...gGggggggggggGg...",
        "..gggggggggggggggg..",
        "..gGgggggggggggGgg..",
        "..gggggggggggggggg..",
        "...ggGgggggggGggg...",
        "....gggggggggggg....",
        "......gggggggg......",
    ], {"g": (74, 132, 58), "G": (58, 108, 46)})
    if berry:
        px = img.load()
        for x, y in ((6, 4), (12, 3), (9, 7), (15, 6), (4, 6)):
            px[x, y] = (226, 66, 58, 255)
            px[x + 1, y] = (240, 120, 104, 255)
    return upscale(outline(img, (40, 78, 34, 255)))


def log():
    """倒下的原木"""
    img = grid([
        "....................",
        "...oooooooooooooo...",
        "..ollbbbbbbbbbbbbo..",
        ".oLlllbbbbbbbbbbbbo.",
        ".oLllbbbbbbbbbbbbbo.",
        "..oooooooooooooooo..",
        "....................",
    ], {"o": (56, 40, 28), "b": (128, 92, 56), "B": (100, 70, 42),
        "l": (150, 112, 70), "L": (176, 138, 90)})
    return upscale(outline(img, (50, 36, 24, 255)))


def stump():
    """砍剩的树桩"""
    img = grid([
        "..oooooo..",
        ".oLLLLLLo.",
        ".oLrLLrLo.",
        ".oLLLLLLo.",
        ".otttttto.",
        ".otttttto.",
        "..oooooo..",
    ], {"o": (56, 40, 28), "L": (176, 138, 90), "r": (146, 108, 68), "t": (110, 78, 46)})
    return upscale(outline(img, (50, 36, 24, 255)))


def mushroom():
    """红帽白点小蘑菇"""
    img = grid([
        "..oooo..",
        ".orrrro.",
        "orrwrrro",
        "orrwrrro",
        ".owwwwo.",
        "..owwo..",
        "..owwo..",
        "..oooo..",
    ], {"o": (60, 40, 34), "r": (208, 74, 58), "w": (240, 234, 220)})
    return upscale(outline(img, (48, 32, 28, 255)))


def main():
    save(upscale(tile_grass(1, dots=True)), "grass.png")
    for f in range(4):
        save(upscale(tile_water(f)), "water%d.png" % f)
    save(pond_edge(), "pond_edge.png")
    for i, (w, h) in enumerate(((240, 170), (270, 140), (220, 120), (250, 120)), 1):
        save(render_patch(w // 2, h // 2, i), "patch%d.png" % i)
    save(upscale(tile_soil(False)), "soil.png")
    save(upscale(tile_soil(True)), "soil_wet.png")
    save(player_sheet(), "player.png")
    save(crops_atlas(), "crops.png")
    save(tree(), "tree.png")
    save(pine(), "tree2.png")
    save(house(), "house.png")
    save(stall(), "stall.png")
    save(fence_post(), "fence_post.png")
    save(fence_rail(), "fence_rail.png")
    save(flowers_atlas(), "flowers.png")
    save(lily(), "lily.png")
    save(stone(), "stone.png")
    save(tuft(), "tuft.png")
    save(shadow(), "shadow.png")
    save(sign(), "sign.png")
    save(lamp(), "lamp.png")
    save(glow(32), "glow.png")
    save(glow(10, (255, 240, 160)), "glow_small.png")
    save(vignette(), "vignette.png")
    save(boulder(), "boulder.png")
    save(branch(), "branch.png")
    save(scarecrow(), "scarecrow.png")
    save(sprinkler(), "sprinkler.png")
    save(fish_icon(), "fish.png")
    save(bobber(), "bobber.png")
    save(well(), "well.png")
    save(mailbox(), "mailbox.png")
    save(bush(True), "bush_berry.png")
    save(bush(False), "bush_plain.png")
    save(log(), "log.png")
    save(stump(), "stump.png")
    save(mushroom(), "mushroom.png")
    print("done ->", OUT)


if __name__ == "__main__":
    main()
