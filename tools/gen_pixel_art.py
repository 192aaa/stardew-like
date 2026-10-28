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


# ---------------- 村民精灵表 ----------------

def npc_sheet(pal, down, up, side):
    """与玩家表同规格：4 列（站/走A/站/走B）x 3 行（下/上/侧），16x22 单元"""
    frames = []
    for body, legbox in ((down, (3, 19, 8, 22)), (up, (3, 19, 8, 22)), (side, (3, 18, 13, 22))):
        base = grid(body, pal)
        walkA = shift_region(base, legbox, 1)
        walkB = shift_region(base, (16 - legbox[2], legbox[1], 16 - legbox[0], legbox[3]), 1)
        frames += [base, walkA, walkB]
    sheet = Image.new("RGBA", (16 * 4, 22 * 3), (0, 0, 0, 0))
    for d in range(3):
        st, wa, wb = frames[d * 3: d * 3 + 3]
        for c, fr in ((0, st), (1, wa), (3, wb)):
            sheet.paste(fr, (c * 16, d * 22))
    return upscale(outline_sheet(sheet, 16, 22))


PAL_ROSA = {
    "o": (44, 36, 30),
    "h": (158, 62, 58), "H": (120, 44, 44),   # 红棕长发
    "s": (248, 208, 160), "e": (48, 40, 34), "m": (206, 122, 100),
    "r": (198, 74, 88), "R": (156, 52, 66),   # 红裙
    "k": (84, 54, 42),
}
ROSA_DOWN = [
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
    "..ohhsssssshho..",
    "...ohhhhhhhho...",
    "...orrrrrrrro...",
    "..orrrrrrrrrro..",
    "..osrrrrrrrrso..",
    "..orrrrrrrrrro..",
    "..oRRRRRRRRRRo..",
    "...orrrrrrrro...",
    "...oRRRRRRRRo...",
    "...orrrrrrrro...",
    "...okkkkkkkko...",
    "....oooooooo....",
]
ROSA_UP = [
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
    "..ohhsssssshho..",
    "...ohhhhhhhho...",
    "...orrrrrrrro...",
    "..orrrrrrrrrro..",
    "..osrrrrrrrrso..",
    "..orrrrrrrrrro..",
    "..oRRRRRRRRRRo..",
    "...orrrrrrrro...",
    "...oRRRRRRRRo...",
    "...orrrrrrrro...",
    "...okkkkkkkko...",
    "....oooooooo....",
]
ROSA_SIDE = [
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
    "...ohhhhhhhho...",
    "...orrrrrrrro...",
    "..orrrrrrrrrro..",
    "..osrrrrrrrrso..",
    "..orrrrrrrrrro..",
    "..oRRRRRRRRRRo..",
    "...orrrrrrrro...",
    "...oRRRRRRRRo...",
    "...orrrrrrrro...",
    "...okkkkkkkko...",
    "....oooooooo....",
]

PAL_BEN = {
    "o": (44, 36, 30),
    "y": (214, 182, 92), "Y": (178, 148, 64),  # 草帽
    "h": (182, 182, 172), "H": (142, 142, 132),  # 灰发
    "s": (234, 188, 142), "e": (48, 40, 34), "m": (196, 116, 96),
    "v": (96, 144, 72), "V": (72, 114, 54),    # 绿马甲
    "w": (226, 220, 200),
    "p": (96, 76, 58), "P": (76, 58, 44),
    "k": (66, 48, 38),
}
BEN_DOWN = [
    "................",
    "....oooooooo....",
    "...oyyyyyyyyo...",
    "..oyyYYYYYYyyo..",
    "..oyyyyyyyyyyo..",
    "...ohhhhhhhho...",
    "..ohssssssshho..",
    "..ohsessssesho..",
    "..ohssssssssho..",
    "..ohsssmmsssho..",
    "...ohssssssho...",
    "....ovvvvvvo....",
    "..owvvvvvvvvwo..",
    "..owvvvvvvvvwo..",
    "..osvvvvvvvvso..",
    "..owwwwwwwwwwo..",
    "...oppppppppo...",
    "...oPpppppppo...",
    "...oppppppppo...",
    "...oppo..oppo...",
    "...okko..okko...",
    "....oooooooo....",
]
BEN_UP = [
    "................",
    "....oooooooo....",
    "...oyyyyyyyyo...",
    "..oyyYYYYYYyyo..",
    "..oyyyyyyyyyyo..",
    "...oyyyyyyyyo...",
    "..ohhhhhhhhhho..",
    "..ohhhhhhhhhho..",
    "..ohhhhhhhhhho..",
    "..ohhhhhhhhhho..",
    "...ohhhhhhhho...",
    "....oVVVVVVo....",
    "..owvvvvvvvvwo..",
    "..owvvvvvvvvwo..",
    "..osvvvvvvvvso..",
    "..owwwwwwwwwwo..",
    "...oppppppppo...",
    "...oPpppppppo...",
    "...oppppppppo...",
    "...oppo..oppo...",
    "...okko..okko...",
    "....oooooooo....",
]
BEN_SIDE = [
    "................",
    "....oooooooo....",
    "...oyyyyyyyyo...",
    "..oyyYYYYYYyyo..",
    "..oyyyyyyyyyyo..",
    "..oyhhhhhhhho...",
    "..ohhssssssho...",
    "..ohhssesssho...",
    "..ohhssssssho...",
    "..ohhssmmssho...",
    "...ohsssssho....",
    "....ovvvvvvo....",
    "...owvvvvvvwo...",
    "...owvvvvvvwo...",
    "...osvvvvvvso...",
    "...owwwwwwwwo...",
    "...oppppppppo...",
    "...oPpppppppo...",
    "...oppppppppo...",
    "...oppppppppo...",
    "...okkkkkkkko...",
    "....oooooooo....",
]


# ---------------- 作物图集 ----------------

PAL_C = {
    "o": (34, 48, 26), "g": (88, 150, 62), "G": (64, 118, 48),
    "y": (168, 190, 86), "w": (238, 226, 168),
    "d": (58, 108, 44), "t": (150, 108, 62), "T": (118, 82, 46),
    "r": (214, 66, 56), "R": (168, 44, 42), "f": (242, 242, 226),
    "n": (232, 128, 44), "N": (196, 92, 32),
    "c": (238, 204, 76), "C": (198, 162, 50), "u": (246, 238, 196),
    "B": (86, 122, 216), "b": (54, 82, 172), "L": (150, 190, 245),
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


def crop_strawberry(stage):
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
            "......gg........",
            ".....g..g.g.....",
            "......gg.g......",
            ".......og.......",
            ".......og.......",
            "......oGg.......",
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
            ".....gg..gg.....",
            "....gggg.gggg...",
            "....gg.gggg.gg..",
            ".....oogggggo...",
            "......oggggo....",
            "......ogGggo....",
            ".....ogGGggo....",
            ".....oGGGGg.....",
            "......oGGg......",
            "................",
            "................",
        ]
    elif stage == 2:
        rows = [
            "................",
            "................",
            "....gg...gg.....",
            "...gggg.gggg....",
            "..gg.gggggg.gg..",
            "..og.gggggg.gg..",
            "...oogffggfgo...",
            "....ogffgffg....",
            ".....oggfgo.....",
            ".....ogggggo....",
            ".....ogGGggo....",
            "....ogGGGGgo....",
            "....oGGGGGg.....",
            ".....oGGGg......",
            "................",
            "................",
        ]
    else:
        rows = [
            "................",
            "................",
            "....gg...gg.....",
            "...gggg.gggg....",
            "..gg.gggggg.gg..",
            "..og.gggggg.gg..",
            "...oogrroggfo...",
            "....ogrRorfro...",
            ".....ogrrgro....",
            "....ogrrrro.....",
            "....ogrRrrgo....",
            ".....ogrrrgo....",
            ".....oGGGGg.....",
            "......oGGg......",
            "................",
            "................",
        ]
    return rows


def crop_pumpkin(stage):
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
            ".......gg.......",
            "....gg.g.g.gg...",
            ".....g.ggg.g....",
            "......ogggo.....",
            ".......oggo.....",
            ".......oGgo.....",
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
            "................",
            "...gg....gg.....",
            "..gggg..gggg.gg.",
            "..gg.gggg.gggg..",
            "...oogggggg.gg..",
            ".....ogggoog....",
            "......oggo......",
            ".....oGgggo.....",
            "......oGGg......",
            "................",
            "................",
        ]
    elif stage == 2:
        rows = [
            "................",
            "................",
            "................",
            "................",
            "..gg......gg....",
            ".gggg....gggg...",
            ".gg.gggggg.gg...",
            "..ooggggggg.....",
            "....oggnngo.....",
            "...oggnNNnngo...",
            "...ognNNNNngo...",
            "...ognNNNNngo...",
            "....ognNNngo....",
            ".....oNNNo......",
            "................",
            "................",
        ]
    else:
        rows = [
            "................",
            "................",
            "................",
            "...gg.....gg....",
            "..gggg...gggg...",
            ".gg..ggggg..gg..",
            ".og.gggggggg....",
            "..oogggnngg.....",
            "....ognnnnno....",
            "...ognnNNnnno...",
            "..ognnNNNNnnno..",
            "..ognNNooNNnno..",
            "..ognnNNNNnnno..",
            "...ognnnnnnno...",
            "....oNNNNNNo....",
            "................",
        ]
    return rows


def crop_corn(stage):
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
            ".......g........",
            "......gg........",
            "....g.og........",
            ".....gog.g......",
            "......og.g......",
            ".......og.......",
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
            ".......g........",
            "....g.gg.g......",
            "...gg.og.gg.....",
            "....ggog.gg.....",
            ".....oogg.......",
            "......ogg.......",
            "......ogg.......",
            "......oGg.......",
            "................",
            "................",
            "................",
        ]
    elif stage == 2:
        rows = [
            "................",
            "................",
            "................",
            "......u.g.......",
            "...g..g.gg..g...",
            "..gg.g.og..gg...",
            "...ggg.og.gg....",
            "....ggooggg.....",
            "......ogg.g.....",
            ".....gogg.......",
            ".....gogg.g.....",
            "......ogg.......",
            "......oGg.......",
            "......oGg.......",
            "................",
            "................",
        ]
    else:
        rows = [
            "................",
            "................",
            ".....uu.uu......",
            "...g.u.g.u.g....",
            "..gg.g.og.gg....",
            "...gggcogc.gg...",
            "....ggcocc.gg...",
            ".....occccog....",
            "...g.occcc.g....",
            "..gg.gogg.gg....",
            "...gggogg.g.....",
            "....ggogg.gg....",
            ".....gogg.g.....",
            "......ogg.......",
            "......oGg.......",
            "................",
        ]
    return rows


def crop_blueberry(stage):
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
            ".....gg.g.......",
            "....gogg.g......",
            ".....ogg........",
            "......og........",
            "................",
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
            "................",
            "....gg...gg.....",
            "..gggg.ggggg....",
            "..ggggggg.ggg...",
            "...ogggggggg....",
            "....ogggggg.....",
            ".....ogggg......",
            ".....oGGg.......",
            "................",
            "................",
            "................",
        ]
    elif stage == 2:
        rows = [
            "................",
            "................",
            "................",
            "....gg....gg....",
            "..gggg..ggggg...",
            ".ggggggggggggg..",
            ".gggLLggggLLgg..",
            "..ggggggggggg...",
            "...ogggggggg....",
            "....oggggggg....",
            ".....oggggg.....",
            "......oGGg......",
            ".....oGGGg......",
            "................",
            "................",
            "................",
        ]
    else:
        rows = [
            "................",
            "................",
            "...gg.....gg....",
            "..gggg.gggggg...",
            ".ggggggggggggg..",
            ".ggBBgggggBBgg..",
            "ggBBBbgggBBBbgg.",
            ".ggBbbgggBbbgg..",
            "..ggBBggggBBg...",
            "...ogggggggg....",
            "....oggggggg....",
            ".....oggggg.....",
            "......oGGg......",
            ".....oGGGg......",
            "................",
            "................",
        ]
    return rows


def crops_atlas():
    art = Image.new("RGBA", (16 * 24, 16), (0, 0, 0, 0))
    order = [crop_parsnip(0), crop_parsnip(1), crop_parsnip(2), crop_parsnip(3),
             crop_potato(0), crop_potato(1), crop_potato(2), crop_potato(3),
             crop_strawberry(0), crop_strawberry(1), crop_strawberry(2), crop_strawberry(3),
             crop_pumpkin(0), crop_pumpkin(1), crop_pumpkin(2), crop_pumpkin(3),
             crop_corn(0), crop_corn(1), crop_corn(2), crop_corn(3),
             crop_blueberry(0), crop_blueberry(1), crop_blueberry(2), crop_blueberry(3)]
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


def render_patch(w, h, seed, pal=None):
    """预渲染农田地块：暗草底 + 深色描边 + 内侧高光 + 割草纹理（pal 可换成雪地调色板）"""
    rng = random.Random(seed)
    if pal is None:
        base, dark, light, edge, hi, stripe = (
            84, 146, 64), (58, 104, 44), (100, 162, 78), (52, 94, 40), (110, 172, 88), (74, 128, 56)
    else:
        base, dark, light, edge, hi, stripe = pal
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
                px[x, (y + x // 3) % h] = stripe + (255,)
    for y in range(h):  # 描边 + 内高光
        for x in range(w):
            if x == 0 or y == 0 or x == w - 1 or y == h - 1:
                px[x, y] = edge + (255,)
            elif x == 1 or y == 1 or x == w - 2 or y == h - 2:
                px[x, y] = hi + (255,)
    return upscale(img)


## 冬季雪地调色板（grass_snow / patch_snow 用）
SNOW_GRASS = dict(base=(210, 221, 233), dark=(190, 203, 217),
                  light=(226, 235, 245), blade=(172, 191, 210))
SNOW_PATCH = ((206, 218, 231), (182, 197, 213), (222, 231, 242),
              (158, 178, 199), (238, 245, 252), (188, 203, 220))


def grass_snow(seed=1):
    rng = random.Random(seed)
    img = Image.new("RGBA", (16, 16))
    px = img.load()
    for y in range(16):
        for x in range(16):
            r = rng.random()
            c = SNOW_GRASS["dark"] if r < 0.16 else (
                SNOW_GRASS["light"] if r < 0.34 else SNOW_GRASS["base"])
            px[x, y] = c + (255,)
    for _ in range(5):  # 雪面浅坑
        x, y = rng.randrange(16), rng.randrange(16)
        px[x, y] = SNOW_GRASS["blade"] + (255,)
        px[(x + 1) % 16, y] = SNOW_GRASS["blade"] + (255,)
    for _ in range(3):  # 冰晶亮点
        x, y = rng.randrange(16), rng.randrange(16)
        px[x, y] = (252, 254, 255, 255)
    return img


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


def fish_gold():
    """鱼王战斗界面的金色鱼（与 fish_icon 同形，换金色）"""
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
    ], {"f": (240, 192, 72), "w": (252, 236, 170), "e": (92, 66, 20)})
    return upscale(outline(img, (128, 94, 24, 255)))


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


def butterfly():
    """两帧蝴蝶图集：展翅 / 收翅（12x8 x2）"""
    pal = {"o": (96, 54, 24), "w": (250, 200, 110), "W": (240, 156, 60), "b": (58, 44, 34)}
    fa = grid([
        ".oo......oo.",
        "owwo....owwo",
        "oWWo....oWWo",
        "oWWWWooWWWWo",
        ".oWoWbbWoWo.",
        "..o..bb..o..",
        ".....bb.....",
        "............",
    ], pal)
    fb = grid([
        "............",
        "...oo..oo...",
        "..oWWooWWo..",
        "...oWbbWo...",
        "....WbbW....",
        ".....bb.....",
        ".....bb.....",
        "............",
    ], pal)
    atlas = Image.new("RGBA", (24, 8), (0, 0, 0, 0))
    atlas.paste(outline(fa, (60, 36, 20, 255)), (0, 0))
    atlas.paste(outline(fb, (60, 36, 20, 255)), (12, 0))
    return upscale(atlas)


def cloud_shadow(seed=7, w=200, h=120):
    """大块柔边云影（alpha 阶梯量化，保持像素风）"""
    rng = random.Random(seed)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    blobs = []
    for _ in range(5):
        blobs.append((rng.uniform(w * 0.28, w * 0.72), rng.uniform(h * 0.32, h * 0.68),
                      rng.uniform(w * 0.16, w * 0.30), rng.uniform(h * 0.20, h * 0.36)))
    for y in range(h):
        for x in range(w):
            v = 0.0
            for cx, cy, rx, ry in blobs:
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if d < 1.0:
                    v += (1.0 - d) ** 1.5
            v = min(1.0, v)
            a = int(v * 4) / 4.0
            if a > 0:
                px[x, y] = (14, 22, 40, int(a * 66))
    return img


def leaf():
    """单片浅色落叶（供粒子 color_initial_ramp 随机着色）"""
    img = grid([
        "..ll..",
        ".llll.",
        "lllLl.",
        ".llll.",
        "..ll..",
        "..s...",
    ], {"l": (222, 218, 202), "L": (240, 238, 224), "s": (180, 176, 160)})
    return upscale(outline(img, (70, 64, 52, 255)))


def dust():
    """脚步尘土小团"""
    img = grid([
        "..ww..",
        ".wwww.",
        "wwWWww",
        "wwWWww",
        ".wwww.",
        "..ww..",
    ], {"w": (214, 206, 188), "W": (238, 232, 218)})
    return upscale(img)


def order_board():
    """订单任务牌：木板 + 钉着白纸（画了几行字）"""
    rows = [
        "....oooooooooooooooo....",
        "...ohhhhhhhhhhhhhhhho...",
        "...ohHHHHHHHHHHHHHHho...",
        "...ohhpppppppppppphho...",
        "...ohhppPPpppppppphho...",
        "...ohhpppppppppppphho...",
        "...ohhpppllllppppphho...",
        "...ohhpppppllllppphho...",
        "...ohhpppllllppppphho...",
        "...ohhpppppppppppphho...",
        "...ohhhhhhhhhhhhhhhho...",
        "....oooooooooooooooo....",
        ".........oppo...........",
        ".........oppo...........",
        ".........oppo...........",
        ".........oppo...........",
        ".........oppo...........",
        ".........oppo...........",
        ".........oppo...........",
        ".........oppo...........",
        ".........oppo...........",
        ".........oppo...........",
        "........ooppppoo........",
        "........oooooooo........",
    ], {
        "o": (56, 40, 28), "h": (150, 108, 64), "H": (176, 132, 82),
        "p": (238, 232, 214), "P": (208, 72, 58), "l": (150, 150, 150),
    }
    img = grid(rows[0], rows[1])
    return upscale(outline(img, (46, 34, 26, 255)))


def coop():
    """鸡舍：小木屋 + 红瓦坡顶 + 门洞 + 小坡道"""
    w, h = 44, 38
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # 墙
    d.rectangle((4, 16, 39, 35), fill=(196, 150, 100, 255))
    for y in range(20, 35, 5):
        d.line((4, y, 39, y), fill=(170, 128, 84, 255))
    # 屋顶
    d.polygon([(0, 18), (22, 2), (43, 18)], fill=(180, 84, 64, 255))
    for y in range(4, 18, 4):
        x0 = 22 - (y - 2) * 21 // 16
        x1 = 22 + (y - 2) * 21 // 16
        d.line((max(x0, 0), y, min(x1, 43), y), fill=(148, 64, 50, 255))
    d.line((0, 18, 43, 18), fill=(120, 52, 42, 255))
    # 门洞
    d.rectangle((16, 24, 27, 35), fill=(74, 50, 34, 255))
    d.rectangle((18, 26, 25, 35), fill=(94, 64, 44, 255))
    # 小窗
    d.rectangle((8, 22, 13, 27), fill=(240, 214, 130, 255))
    # 坡道
    d.polygon([(16, 35), (27, 35), (31, 37), (12, 37)], fill=(150, 108, 64, 255))
    return upscale(outline(img, (52, 40, 32, 255)))


def chicken_sheet():
    """白母鸡两帧（站立 / 迈步），侧面朝右，flip_h 转向"""
    pal = {
        "o": (54, 42, 32), "w": (246, 242, 230), "W": (214, 206, 192),
        "e": (40, 36, 30), "y": (238, 170, 60), "r": (210, 70, 60),
    }
    top = [
        "....ooooo.......",
        "...orrrrro......",
        "...owwwwwo......",
        "...owewwwwo.....",
        "...owwwwwyyo....",
        "....oowwwyyo....",
        "...owwwwoo......",
        "..owwwwwwo......",
        ".owwwwwwwwo.....",
        ".owwwwwwwwo.....",
        ".oWwwwwwwWo.....",
        "..owwwwwo.......",
    ]
    f1 = top + ["...oo.oo........"]
    f2 = top + ["..oo...oo......."]
    atlas = Image.new("RGBA", (32, 13), (0, 0, 0, 0))
    atlas.paste(outline(grid(f1, pal), (48, 38, 30, 255)), (0, 0))
    atlas.paste(outline(grid(f2, pal), (48, 38, 30, 255)), (16, 0))
    return upscale(atlas)


def egg():
    """一颗白鸡蛋"""
    img = grid([
        "..oooo..",
        ".owwwo..",
        "owwWwwo.",
        "owwwwwo.",
        "oWwwwWo.",
        ".ooooo..",
    ], {"o": (150, 120, 70), "w": (246, 238, 214), "W": (222, 210, 182)})
    return upscale(outline(img, (110, 88, 52, 255)))


def machine_mayo():
    """蛋黄酱机：木箱机身 + 顶部玻璃罐（装蛋黄酱）+ 侧面摇柄"""
    img = grid([
        "......oooo......",
        ".....oggggo.....",
        ".....ogYYgo.....",
        ".....ogYYgo.....",
        ".....oggggo.....",
        "...oooooooooo..c",
        "...oBBBBBBBBo..c",
        "...obBBBBBBbo..c",
        "...obBBBBBBbo.oc",
        "...obbbbbbbbo.oc",
        "...oooooooooo.o.",
        "....oo....oo....",
    ], {
        "o": (56, 42, 30), "g": (208, 224, 232), "Y": (242, 206, 92),
        "B": (198, 152, 102), "b": (172, 128, 84), "c": (122, 120, 130),
    })
    return upscale(outline(img, (44, 34, 26, 255)))


def machine_jam():
    """食品加工机：铜锅 + 红色果酱 + 底座炉身"""
    img = grid([
        ".....oooooo.....",
        "....okkkkkko....",
        "...okrrRRrrko...",
        "...okrRRRRrko...",
        "...okrrRRrrko...",
        "...okkkkkkkko...",
        ".....o....o.....",
        "...okkkkkkkko...",
        "...okKKKKKKko...",
        "...okkkkkkkko...",
        "....oooooooo....",
    ], {
        "o": (50, 36, 26), "k": (160, 96, 62), "K": (206, 132, 84),
        "r": (196, 60, 52), "R": (232, 104, 84),
    })
    return upscale(outline(img, (40, 30, 22, 255)))


def stove():
    """灶台：石砌炉身 + 黑铁锅 + 炉膛火光"""
    img = grid([
        "......pppp......",
        ".....opppppo....",
        "....opppppppo...",
        "...oooooooooo...",
        "..okkKKkkkKKko..",
        "..okkkKKkkkkko..",
        "..oKKkkkKKkkko..",
        "..okkkkkkkKKko..",
        "..okkfFFfkkkko..",
        "..okffFFffkkko..",
        "..okkfFFfkkkko..",
        "..okkkkkkkkkko..",
        "..okkKKkkkKKko..",
        "...oooooooooo...",
    ], {
        "o": (40, 30, 24), "p": (46, 42, 46), "k": (108, 100, 108),
        "K": (146, 138, 144), "f": (226, 108, 40), "F": (248, 186, 80),
    })
    return upscale(outline(img, (36, 26, 20, 255)))


def ore_node(vein):
    """矿岩节点：灰岩块 + 彩色矿脉（铜/铁/宝石）"""
    img = grid([
        "....oooooo....",
        "..oorrrrrroo..",
        ".orrRRrrrrrro.",
        ".orvvvRrrrrro.",
        "orrRvvrrrrRrro",
        "orrrrrrrvvRrro",
        "orrvvRrrrrrrro",
        ".orrrrvvRrrro.",
        "..oorrrrrroo..",
        "....oooooo....",
    ], {
        "o": (58, 56, 64), "r": (138, 136, 148), "R": (168, 166, 178), "v": vein,
    })
    return upscale(outline(img, (40, 38, 46, 255)))


def mine_arch():
    """矿洞入口：石拱 + 黑洞口 + 支撑木梁"""
    w, h = 30, 26
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(1, 25), (1, 12), (8, 3), (21, 3), (28, 12), (28, 25)],
              fill=(128, 124, 134, 255))
    d.polygon([(4, 25), (4, 13), (9, 6), (20, 6), (25, 13), (25, 25)],
              fill=(152, 148, 158, 255))
    d.polygon([(8, 25), (8, 14), (11, 9), (18, 9), (21, 14), (21, 25)],
              fill=(28, 24, 34, 255))
    d.polygon([(10, 25), (10, 15), (12, 11), (17, 11), (19, 15), (19, 25)],
              fill=(14, 12, 20, 255))
    d.rectangle((7, 8, 9, 25), fill=(110, 78, 50, 255))
    d.rectangle((20, 8, 22, 25), fill=(110, 78, 50, 255))
    d.rectangle((6, 5, 23, 8), fill=(130, 92, 58, 255))
    return upscale(outline(img, (46, 42, 50, 255)))


def pet_sheet(body, legs_a, legs_b, pal):
    """两帧侧面宠物精灵表：身体 + 两组腿部姿势，横排成图集"""
    w = len(body[0])
    h = len(body) + len(legs_a)
    atlas = Image.new("RGBA", (w * 2, h), (0, 0, 0, 0))
    atlas.paste(outline(grid(body + legs_a, pal), (56, 42, 32, 255)), (0, 0))
    atlas.paste(outline(grid(body + legs_b, pal), (56, 42, 32, 255)), (w, 0))
    return upscale(atlas)


CAT_BODY = [
    ".oo.oo..........",
    ".occooo.........",
    ".occccco........",
    ".ocecccco.......",
    ".occccccoooooo..",
    ".occcccccccccco.",
    ".ocCcccccccccCo.",
    "..occccccccccCo.",
    "..occccccccco.oo",
    "..occcccccco..oo",
]
CAT_LEGS_A = ["..oo..oo........"]
CAT_LEGS_B = ["...oo....oo....."]
CAT_PAL = {
    "o": (74, 56, 42), "c": (224, 150, 90), "C": (240, 182, 122),
    "e": (40, 36, 30),
}

DOG_BODY = [
    ".oo.............",
    ".oo..ooo........",
    ".oooocddoo......",
    ".oddeddddo......",
    ".odddddddooooo..",
    ".odwddddddddddo.",
    ".oDwddddddddddo.",
    "..oddddddddddo..",
    "..odddddddddo.o.",
    "..oddddddddo....",
]
DOG_LEGS_A = ["..oo..oo........"]
DOG_LEGS_B = ["...oo....oo....."]
DOG_PAL = {
    "o": (74, 56, 42), "d": (172, 124, 80), "D": (196, 146, 98),
    "e": (40, 36, 30), "w": (250, 246, 238),
}


def bunting():
    """节日彩旗：一根绳 + 红黄绿蓝三角旗交替"""
    w, h = 96, 12
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.line((0, 2, 95, 2), fill=(140, 110, 70, 255))
    cols = [(214, 80, 66), (240, 200, 90), (110, 180, 100), (110, 150, 220)]
    for i in range(8):
        x0 = 3 + i * 12
        d.polygon([(x0, 3), (x0 + 8, 3), (x0 + 4, 11)], fill=cols[i % 4] + (255,))
    return upscale(outline(img, (60, 46, 32, 255)))


def _pad(rows, w):
    """右侧补齐透明像素，省得逐行数字符"""
    out = []
    for r in rows:
        assert len(r) <= w, "行超宽: %d > %d [%s]" % (len(r), w, r)
        out.append(r + "." * (w - len(r)))
    return out


def furnace():
    """熔炉：石砌炉身 + 侧面烟囱 + 橙红炉口（熔炼金属锭）"""
    img = grid(_pad([
        ".ppp",
        ".pXp",
        ".ppp",
        "...oooooooooo",
        "..okkKKkkkKKko",
        "..okkkkkkkkkko",
        "..okkkkkkkkkko",
        "..okfFFFFfkkko",
        "..okfFFFFfkkko",
        "..okffFFffkkko",
        "..okkfFFfkkkko",
        "..okkkkkkkkkko",
        "..okkKKkkkKKko",
        "...oooooooooo",
    ], 16), {
        "o": (40, 30, 24), "p": (122, 118, 128), "X": (64, 60, 72),
        "k": (108, 100, 108), "K": (146, 138, 144),
        "f": (226, 108, 40), "F": (248, 186, 80),
    })
    return upscale(outline(img, (36, 26, 20, 255)))


def machine_cheese():
    """奶酪机：木桶压酪器（顶部压杆 + 桶身 + 奶酪黄）"""
    img = grid([
        "......opppo.....",
        "......o.p.o.....",
        "...oooooooooo...",
        "..oBBBBBBBBBBo..",
        "..obBBBBBBBBbo..",
        "..obBBBBBBBBbo..",
        "..obyBBBBBybo...",
        "..obyyBByybbo...",
        "..obbbbbbbbbo...",
        "..oBBBBBBBBBBo..",
        "..obbbbbbbbbo...",
        "...oooooooooo...",
    ], {
        "o": (50, 38, 28), "p": (122, 120, 130),
        "B": (198, 154, 104), "b": (170, 128, 84), "y": (242, 200, 92),
    })
    return upscale(outline(img, (40, 30, 22, 255)))


def barn():
    """畜棚：宽木棚 + 红棕屋顶 + 大门洞 + 干草垛"""
    w, h = 44, 38
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # 墙（暖白木板）
    d.rectangle((3, 18, 40, 35), fill=(214, 192, 156, 255))
    for y in range(22, 35, 5):
        d.line((3, y, 40, y), fill=(188, 166, 130, 255))
    # 屋顶（红棕梯形）
    d.polygon([(0, 20), (10, 4), (33, 4), (43, 20)], fill=(150, 74, 56, 255))
    for y in range(6, 20, 4):
        inset = (y - 4) * 21 // 16
        d.line((max(10 - inset, 0), y, min(33 + inset, 43), y),
               fill=(122, 58, 46, 255))
    d.line((0, 20, 43, 20), fill=(96, 46, 38, 255))
    # 大门洞
    d.rectangle((14, 24, 29, 35), fill=(84, 56, 36, 255))
    d.rectangle((16, 26, 27, 35), fill=(106, 72, 46, 255))
    d.line((21, 26, 21, 35), fill=(84, 56, 36, 255))
    # 干草垛
    d.rectangle((5, 28, 11, 35), fill=(226, 186, 92, 255))
    for y in range(30, 35, 3):
        d.line((5, y, 11, y), fill=(198, 158, 70, 255))
    # 小窗
    d.rectangle((33, 24, 38, 29), fill=(240, 214, 130, 255))
    return upscale(outline(img, (52, 40, 32, 255)))


def _quadruped(top, legs_a, legs_b, pal, w=20, fh=15):
    """四足动物精灵表：上身为 13 行，两组腿部姿势各 2 行，横排图集"""
    atlas = Image.new("RGBA", (w * 2, fh), (0, 0, 0, 0))
    atlas.paste(outline(grid(_pad(top + legs_a, w), pal), (48, 38, 30, 255)), (0, 0))
    atlas.paste(outline(grid(_pad(top + legs_b, w), pal), (48, 38, 30, 255)), (w, 0))
    return upscale(atlas)


def cow_sheet():
    """奶牛两帧（站立 / 迈步），侧面朝右，白底黑斑 + 粉色乳房"""
    pal = {
        "o": (54, 42, 32), "w": (240, 236, 226), "W": (216, 210, 198),
        "k": (64, 60, 66), "e": (40, 36, 30), "p": (238, 168, 176),
    }
    top = [
        "......ooooo",
        ".....okkkkkoo",
        ".....okwwwwwko",
        ".....owewwwwko",
        ".....owwwwkppoo",
        "......oowwwkppo",
        "....oowwwwoo",
        "...owkwwwwwwwo",
        "..owwwwwwwwwwwwo",
        "..owkwwwwwwkwwwo",
        "..owwwwwwwwwwwwo",
        "..oWwwwwwwwwwwWo",
        "...owwpwwwwpwo",
    ]
    la = ["...oo....oo", "...oo....oo"]
    lb = ["..oo......oo", ".oo........oo"]
    return _quadruped(top, la, lb, pal)


def sheep_sheet():
    """绵羊两帧（站立 / 迈步），侧面朝右，蓬松羊毛 + 灰脸"""
    pal = {
        "o": (54, 42, 32), "f": (246, 244, 238), "F": (220, 216, 206),
        "k": (110, 102, 98), "e": (40, 36, 30),
    }
    top = [
        "......offfffo",
        "....offffffffffo",
        "...offfffffffffo",
        "...offffffffffko",
        "...offffffffffkeko",
        "....oofffffffokko",
        "...offffffffoo",
        "..offfffffffffo",
        ".offffffffffffffo",
        ".oFffffffffffffFo",
        ".oFffffffffffffFo",
        "..offffffffffffo",
        "...offfffffffo",
    ]
    la = ["...oo....oo", "...oo....oo"]
    lb = ["..oo......oo", ".oo........oo"]
    return _quadruped(top, la, lb, pal, w=19)


def sprinkler2():
    """高级洒水器：金色喷头 + 底座（清晨浇灌 3x3）"""
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
    ], {"s": (222, 184, 80), "g": (158, 122, 44)})
    return upscale(outline(img, (100, 78, 30, 255)))


def milk():
    """一瓶牛奶"""
    img = grid([
        "..oo...",
        ".oppo..",
        ".owwo..",
        "owwWWwo",
        "owwWWwo",
        "oWwwwWo",
        ".ooooo.",
    ], {"o": (120, 130, 150), "p": (188, 196, 214), "w": (248, 248, 244), "W": (226, 230, 240)})
    return upscale(outline(img, (86, 94, 116, 255)))


def wool():
    """一团蓬松羊毛"""
    img = grid([
        ".ffff.",
        "ffFfff",
        "ffffFf",
        "fFffff",
        ".ffff.",
        "..ff..",
    ], {"f": (246, 244, 238), "F": (218, 214, 204)})
    return upscale(outline(img, (150, 146, 138, 255)))


# ---------------- 8-bit 音效（wave 模块合成） ----------------
import math
import struct
import wave as wave_mod

SR = 22050


def _write_wav(name, samples):
    with wave_mod.open(os.path.join(OUT, name), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32000)) for s in samples))
    print("saved", name, "%.2fs" % (len(samples) / float(SR)))


def _env(i, n, att=0.005, curve=1.8):
    """attack + 指数衰减包络"""
    t = i / float(n)
    at = min(1.0, t / att) if att > 0 else 1.0
    return at * (1.0 - t) ** curve


def _dur(d):
    return int(SR * d)


def sfx_hoe():
    """锄地：低频闷响 + 短促摩擦噪声"""
    rng = random.Random(1)
    ph = [0.0]
    n = _dur(0.16)

    def fn(i):
        t = i / float(n)
        ph[0] += 95.0 * (1.0 - 0.55 * t) / SR
        sq = 1.0 if ph[0] % 1.0 < 0.5 else -1.0
        nz = (rng.random() * 2 - 1) * (0.6 if t < 0.25 else 0.0)
        return (sq * 0.5 + nz) * _env(i, n, 0.004, 1.8)

    _write_wav("s_hoe.wav", [fn(i) for i in range(n)])


def sfx_water():
    """浇水：低通噪声水花 + 起伏"""
    rng = random.Random(2)
    lp = [0.0]
    n = _dur(0.28)

    def fn(i):
        t = i / float(n)
        raw = rng.random() * 2 - 1
        lp[0] += (raw - lp[0]) * (0.26 - 0.13 * t)
        wob = 0.75 + 0.25 * math.sin(t * 40)
        return lp[0] * wob * _env(i, n, 0.01, 1.4) * 2.2

    _write_wav("s_water.wav", [fn(i) for i in range(n)])


def sfx_plant():
    """播种/放置：柔和三角波下落 pop"""
    ph = [0.0]
    n = _dur(0.13)

    def fn(i):
        t = i / float(n)
        ph[0] += 320.0 * (1.0 - 0.45 * t) / SR
        tri = 4 * abs(ph[0] % 1.0 - 0.5) - 1
        return tri * _env(i, n, 0.004, 2.2) * 0.6

    _write_wav("s_plant.wav", [fn(i) for i in range(n)])


def sfx_harvest():
    """收获：C5-E5-G5 上行琶音（方波）"""
    notes = [523.25, 659.25, 783.99]
    seg = _dur(0.10)
    ph = [0.0]

    def fn(i):
        idx = min(i // seg, 2)
        ph[0] += notes[idx] / SR
        sq = 1.0 if ph[0] % 1.0 < 0.5 else -1.0
        li = i - idx * seg
        return sq * 0.4 * _env(li, seg, 0.006, 1.6)

    _write_wav("s_harvest.wav", [fn(i) for i in range(seg * 3)])


def sfx_coin():
    """金币：经典 B5->E6 双音"""
    ph = [0.0]
    n = _dur(0.28)
    split = _dur(0.08)

    def fn(i):
        ph[0] += (987.77 if i < split else 1318.5) / SR
        sq = 1.0 if ph[0] % 1.0 < 0.5 else -1.0
        li = i - split if i >= split else i
        return sq * 0.35 * _env(li, n - split, 0.002, 1.5)

    _write_wav("s_coin.wav", [fn(i) for i in range(n)])


def sfx_bite():
    """鱼咬钩：快速下滑水泡 plop"""
    ph = [0.0]
    n = _dur(0.22)

    def fn(i):
        t = i / float(n)
        f = 420.0 * (1.0 - 0.72 * t) * (1.0 + 0.08 * math.sin(t * 60))
        ph[0] += f / SR
        s = math.sin(ph[0] * 2 * math.pi) * 0.7 + (1.0 if ph[0] % 1.0 < 0.5 else -1.0) * 0.3
        return s * _env(i, n, 0.004, 1.6)

    _write_wav("s_bite.wav", [fn(i) for i in range(n)])


def sfx_pick():
    """摘野莓：两声三角波 blip"""
    ph = [0.0]
    n = _dur(0.15)
    split = _dur(0.06)

    def fn(i):
        ph[0] += (660.0 if i < split else 880.0) / SR
        tri = 4 * abs(ph[0] % 1.0 - 0.5) - 1
        li = i - split if i >= split else i
        return tri * 0.55 * _env(li, n - split, 0.004, 1.8)

    _write_wav("s_pick.wav", [fn(i) for i in range(n)])


def sfx_axe():
    """斧镐：噪声脆响 + 低频 thunk"""
    rng = random.Random(3)
    ph = [0.0]
    n = _dur(0.17)

    def fn(i):
        t = i / float(n)
        ph[0] += 70.0 / SR
        sq = 1.0 if ph[0] % 1.0 < 0.5 else -1.0
        nz = (rng.random() * 2 - 1) * (1.0 - t)
        return (sq * 0.55 + nz * 0.7) * _env(i, n, 0.002, 2.0)

    _write_wav("s_axe.wav", [fn(i) for i in range(n)])


def sfx_talk():
    """对话：两个上扬的短促方波音"""
    out = []
    for f, d in ((660, 0.055), (990, 0.07)):
        n = _dur(d)
        ph = 0.0
        for i in range(n):
            ph += f / SR
            out.append((1.0 if ph % 1.0 < 0.5 else -1.0) * 0.26 * _env(i, n, 0.004, 1.2))
    _write_wav("s_talk.wav", out)


def sfx_rain():
    """雨声环境音：低通噪声 + 缓慢起伏，可无缝循环"""
    rng = random.Random(7)
    n = _dur(4.0)
    lp = 0.0
    out = []
    for i in range(n):
        w = rng.random() * 2 - 1
        lp += 0.22 * (w - lp)
        wob = 0.72 + 0.28 * math.sin(i / float(SR) * math.pi * 1.0)
        out.append(lp * 1.15 * wob)
    _write_wav("s_rain.wav", out)


# ---------------- 8-bit BGM（方波旋律 + 三角波贝斯 + 噪声踩镲） ----------------

def _note_freq(m):
    return 440.0 * (2.0 ** ((m - 69) / 12.0))


def _wave_sq(ph, duty=0.5):
    return 1.0 if (ph % 1.0) < duty else -1.0


def _wave_tri(ph, _duty=0.5):
    p = ph % 1.0
    return 4.0 * p - 1.0 if p < 0.5 else 3.0 - 4.0 * p


def _render_track(events, wave, amp, bpm, duty=0.5):
    """events: [(midi, beats)]，midi=0 为休止；返回采样列表"""
    total = int(SR * 60.0 / bpm * sum(b for _, b in events))
    out = [0.0] * total
    i = 0
    for midi, beats in events:
        n = int(SR * 60.0 / bpm * beats)
        if midi > 0:
            f = _note_freq(midi)
            ph = 0.0
            for k in range(n):
                ph += f / SR
                out[i + k] += amp * wave(ph, duty) * _env(k, n, 0.012, 0.8)
        i += n
    return out


def _hats(total_n, bpm, amp, every=1, seed=11):
    rng = random.Random(seed)
    beat_n = int(SR * 60.0 / bpm)
    out = [0.0] * total_n
    n = int(SR * 0.045)
    for b in range(0, total_n // beat_n + 1, every):
        for k in range(n):
            if b * beat_n + k < total_n:
                out[b * beat_n + k] += amp * (rng.random() * 2 - 1) * _env(k, n, 0.001, 2.5)
    return out


def _bgm_write(name, tracks):
    n = max(len(t) for t in tracks)
    mixed = [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]
    peak = max(abs(s) for s in mixed) or 1.0
    mixed = [s / peak * 0.78 for s in mixed]
    _write_wav(name, mixed)


def bgm_day():
    """白日主题：132 BPM C 大调，轻快方波旋律"""
    bpm = 132
    b1 = [(76, .5), (79, .5), (81, .5), (79, .5), (76, .5), (79, .5), (81, .5), (84, .5)]
    b2 = [(81, .5), (79, .5), (76, .5), (74, .5), (72, .5), (74, .5), (76, 1)]
    b3 = [(74, .5), (76, .5), (74, .5), (72, .5), (69, .5), (72, .5), (74, .5), (76, .5)]
    b4 = [(72, .5), (69, .5), (67, .5), (69, .5), (72, 1), (0, 1)]
    b5 = [(79, .5), (81, .5), (79, .5), (76, .5), (74, .5), (76, .5), (74, .5), (72, .5)]
    b6 = [(74, .5), (72, .5), (69, .5), (67, .5), (72, 1), (0, 1)]
    melody = b1 + b2 + b3 + b4 + b1 + b2 + b5 + b6
    bass = []
    for root in (48, 48, 41, 43, 48, 48, 41, 43):
        bass += [(root, 1), (root + 7, 1), (root, 1), (root + 7, 1)]
    lead = _render_track(melody, _wave_sq, 0.16, bpm, 0.32)
    low = _render_track(bass, _wave_tri, 0.22, bpm)
    beats_n = int(SR * 60.0 / bpm * sum(b for _, b in melody))
    hats = _hats(beats_n, bpm, 0.06, 1)
    _bgm_write("bgm_day.wav", [lead, low, hats])


def bgm_night():
    """夜晚主题：84 BPM A 小调，舒缓三角波"""
    bpm = 84
    melody = [
        (69, 1), (72, 1), (76, 2),
        (74, 1), (72, 1), (69, 2),
        (67, 1), (69, 1), (72, 2),
        (64, 2), (0, 2),
        (69, 1), (72, 1), (76, 2),
        (79, 1), (76, 1), (72, 2),
        (74, 1), (76, 1), (74, 1), (72, 1),
        (69, 2), (0, 2),
    ]
    bass = []
    for root in (45, 45, 41, 43, 45, 41, 43, 45):
        bass += [(root, 4)]
    lead = _render_track(melody, _wave_tri, 0.2, bpm)
    low = _render_track(bass, _wave_tri, 0.14, bpm)
    _bgm_write("bgm_night.wav", [lead, low])


def main():
    save(upscale(tile_grass(1, dots=True)), "grass.png")
    save(upscale(grass_snow()), "grass_snow.png")
    for f in range(4):
        save(upscale(tile_water(f)), "water%d.png" % f)
    save(pond_edge(), "pond_edge.png")
    for i, (w, h) in enumerate(((240, 170), (270, 140), (220, 120), (250, 120)), 1):
        save(render_patch(w // 2, h // 2, i), "patch%d.png" % i)
        save(render_patch(w // 2, h // 2, i, SNOW_PATCH), "patch_snow%d.png" % i)
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
    save(fish_gold(), "fish_gold.png")
    save(bobber(), "bobber.png")
    save(well(), "well.png")
    save(mailbox(), "mailbox.png")
    save(bush(True), "bush_berry.png")
    save(bush(False), "bush_plain.png")
    save(log(), "log.png")
    save(stump(), "stump.png")
    save(mushroom(), "mushroom.png")
    save(butterfly(), "butterfly.png")
    save(cloud_shadow(), "cloud_shadow.png")
    save(leaf(), "leaf.png")
    save(dust(), "dust.png")
    save(npc_sheet(PAL_ROSA, ROSA_DOWN, ROSA_UP, ROSA_SIDE), "villager_rosa.png")
    save(npc_sheet(PAL_BEN, BEN_DOWN, BEN_UP, BEN_SIDE), "villager_ben.png")
    save(order_board(), "order_board.png")
    save(coop(), "coop.png")
    save(chicken_sheet(), "chicken.png")
    save(egg(), "egg.png")
    save(machine_mayo(), "machine_mayo.png")
    save(machine_jam(), "machine_jam.png")
    save(stove(), "stove.png")
    save(ore_node((222, 120, 60)), "ore_copper.png")
    save(ore_node((210, 212, 224)), "ore_iron.png")
    save(ore_node((140, 116, 232)), "ore_gem.png")
    save(mine_arch(), "mine_arch.png")
    save(pet_sheet(CAT_BODY, CAT_LEGS_A, CAT_LEGS_B, CAT_PAL), "pet_cat.png")
    save(pet_sheet(DOG_BODY, DOG_LEGS_A, DOG_LEGS_B, DOG_PAL), "pet_dog.png")
    save(bunting(), "bunting.png")
    save(furnace(), "furnace.png")
    save(machine_cheese(), "machine_cheese.png")
    save(barn(), "barn.png")
    save(cow_sheet(), "cow.png")
    save(sheep_sheet(), "sheep.png")
    save(sprinkler2(), "sprinkler2.png")
    save(milk(), "milk.png")
    save(wool(), "wool.png")
    for fn in (sfx_hoe, sfx_water, sfx_plant, sfx_harvest, sfx_coin, sfx_bite, sfx_pick, sfx_axe,
               sfx_talk, sfx_rain):
        fn()
    bgm_day()
    bgm_night()
    print("done ->", OUT)


if __name__ == "__main__":
    main()
