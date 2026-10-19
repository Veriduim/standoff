"""The icon fonts the game carries (19 Oct 13:58, the web version: a browser has no system fonts to borrow, so every
icon and emoji drew as a box). Godot's own font (Open Sans) has letters, not icons; these two small fonts hold just the
icons the game's text uses, and Ui adds them behind it - the same icons on every phone, Android included.

  python tools/icon_fonts.py <folder with the full fonts>   # remake assets/fonts/icons_*.ttf from the game's text
  python tools/icon_fonts.py --list                         # just list the characters the game's text uses

The full fonts (SIL Open Font License, licences in assets/fonts/):
  NotoColorEmoji.ttf            https://github.com/googlefonts/noto-emoji (2D/fonts) - colour pictures (CBDT, which
                                Godot draws; the COLRv1 version it can't)
  NotoSansSymbols2-Regular.ttf  https://github.com/notofonts/symbols - plain symbols (shapes, the menu's lines)
  NotoSansMath-Regular.ttf      https://github.com/notofonts/math - the arrows (Symbols 2 hasn't got them)
The emoji font gets every character that's an emoji picture by default, plus ICON_AS_EMOJI; each of the rest comes from
the first plain font that has it. ui_test's icon check fails when the game's text uses a character none of the fonts has.
"""
import io
import os
import sys
import unicodedata

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SCRIPTS = os.path.join(ROOT, "scripts")
OUT = os.path.join(ROOT, "assets", "fonts")
SKIP = ("tests", "dev")
OPEN_SANS = set(range(0x20, 0x7F)) | {0xB7, 0xD7, 0x2014, 0x2018, 0x2019, 0x201C, 0x201D, 0x2026, 0x2212, 0x221E}
## Open Sans's line (ascent, descent, as a share of the em): Godot sizes a line by the tallest font in the chain, so an
## icon font with a deeper line made EVERY button and label taller (Noto Sans Symbols 2: descent 0.63 - lines 31 -> 38
## px at size 22, the home card ran off the screen). Each icon font's line is clipped to this; the icons still draw.
LINE = (1.069, 0.293)
ICON_AS_EMOJI = {0x23F1, 0x1F6E1, 0x26A0}   # (stopwatch, shield, warning: drawn in colour like the other badges)
EMOJI_DEFAULT = set()   # (Emoji_Presentation=Yes for the blocks we use - filled below)
for lo, hi in [(0x231A, 0x231B), (0x23E9, 0x23EC), (0x23F0, 0x23F0), (0x23F3, 0x23F3), (0x25FD, 0x25FE),
               (0x2614, 0x2615), (0x2648, 0x2653), (0x267F, 0x267F), (0x2693, 0x2693), (0x26A1, 0x26A1),
               (0x26AA, 0x26AB), (0x26BD, 0x26BE), (0x26C4, 0x26C5), (0x26CE, 0x26CE), (0x26D4, 0x26D4),
               (0x26EA, 0x26EA), (0x26F2, 0x26F3), (0x26F5, 0x26F5), (0x26FA, 0x26FA), (0x26FD, 0x26FD),
               (0x2705, 0x2705), (0x270A, 0x270B), (0x2728, 0x2728), (0x274C, 0x274C), (0x274E, 0x274E),
               (0x2753, 0x2755), (0x2757, 0x2757), (0x2795, 0x2797), (0x27B0, 0x27B0), (0x27BF, 0x27BF),
               (0x2B1B, 0x2B1C), (0x2B50, 0x2B50), (0x2B55, 0x2B55), (0x1F000, 0x1FAFF)]:
    EMOJI_DEFAULT |= set(range(lo, hi + 1))
EMOJI_DEFAULT -= {0x1F6E1}   # (text by default - ICON_AS_EMOJI puts it back)


def strings(line):
    """The string literals on a line of GDScript (a comment's text isn't on screen)."""
    out, i, n = [], 0, len(line)
    while i < n:
        c = line[i]
        if c == "#":
            break
        if c in "\"'":
            triple = line[i:i + 3] == c * 3
            j = i + (3 if triple else 1)
            buf = []
            while j < n:
                if line[j] == "\\":
                    buf.append(line[j:j + 2])
                    j += 2
                    continue
                if (triple and line[j:j + 3] == c * 3) or (not triple and line[j] == c):
                    break
                buf.append(line[j])
                j += 1
            out.append("".join(buf))
            i = j + (3 if triple else 1)
            continue
        i += 1
    return out


def used():
    """Every character outside plain ASCII in the game's text -> where."""
    seen = {}
    for dp, _dn, fn in os.walk(SCRIPTS):
        if any(s in dp.replace("\\", "/").split("/") for s in SKIP):
            continue
        for f in sorted(fn):
            if f.endswith(".gd"):
                for k, line in enumerate(io.open(os.path.join(dp, f), encoding="utf-8"), 1):
                    for s in strings(line):
                        for ch in s:
                            if ord(ch) > 127:
                                seen.setdefault(ord(ch), "%s:%d" % (f, k))
    return seen


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    seen = used()
    need = sorted(c for c in seen if c not in OPEN_SANS)
    emoji = [c for c in need if c in EMOJI_DEFAULT or c in ICON_AS_EMOJI]
    symbols = [c for c in need if c not in emoji]
    for c in need:
        print("U+%04X %s %-6s %-36s %s" % (c, chr(c), "emoji" if c in emoji else "symbol",
                                          unicodedata.name(chr(c), "?")[:36], seen[c]))
    if len(sys.argv) < 2 or sys.argv[1] == "--list":
        return
    from fontTools import subset
    from fontTools.ttLib import TTFont
    src = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    plan = [["icons_emoji.ttf", "NotoColorEmoji.ttf", emoji]]
    left = list(symbols)
    for name, full in [("icons_symbols.ttf", "NotoSansSymbols2-Regular.ttf"), ("icons_arrows.ttf", "NotoSansMath-Regular.ttf")]:
        have = TTFont(os.path.join(src, full)).getBestCmap()
        plan.append([name, full, [c for c in left if c in have]])
        left = [c for c in left if c not in have]
    have = TTFont(os.path.join(src, "NotoColorEmoji.ttf")).getBestCmap()
    left += [c for c in emoji if c not in have]
    if left:
        sys.exit("no font has %s" % " ".join("U+%04X" % c for c in left))
    for name, full, cps in plan:
        if not cps:
            continue
        opts = subset.Options()
        opts.layout_features = []
        opts.hinting = False
        opts.name_IDs = ["*"]   # (keep the copyright and licence lines)
        opts.notdef_outline = True
        font = TTFont(os.path.join(src, full))
        sub = subset.Subsetter(opts)
        sub.populate(unicodes=cps)
        sub.subset(font)
        upm = font["head"].unitsPerEm
        asc, desc = int(LINE[0] * upm), int(LINE[1] * upm)
        hhea, os2 = font["hhea"], font["OS/2"]
        hhea.ascent, hhea.descent, hhea.lineGap = min(hhea.ascent, asc), max(hhea.descent, -desc), 0
        os2.sTypoAscender, os2.sTypoDescender, os2.sTypoLineGap = min(os2.sTypoAscender, asc), max(os2.sTypoDescender, -desc), 0
        os2.usWinAscent, os2.usWinDescent = min(os2.usWinAscent, asc), min(os2.usWinDescent, desc)
        font.save(os.path.join(OUT, name))
        print("%s: %d icons, %d bytes" % (name, len(cps), os.path.getsize(os.path.join(OUT, name))))


if __name__ == "__main__":
    main()
