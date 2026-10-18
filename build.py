#!/usr/bin/env python3
"""
build.py — prepare photos for the Loop page.

What it does, per photo in the source folder:
  - fixes orientation and strips EXIF (removes GPS and other personal data)
  - writes a small thumbnail and a large version, both WebP
  - records aspect ratio and colour groups (for the Colour filter)
It then writes photos.json, the index the Loop page reads.
Re-runs only process new photos.

Usage:
  pip install pillow
  python3 build.py /path/to/your/originals

Output (next to this script):
  loop/photos/thumb/<id>.webp
  loop/photos/full/<id>.webp
  loop/photos.json
"""

import sys, os, io, json, re, hashlib, colorsys
from collections import Counter
from PIL import Image, ImageOps

# ---- settings ----
COLOURS = ["warm", "green", "cool", "purple", "neutral"]
THUMB_LONG = 240      # px, long side, for the far view
FULL_LONG  = 1600     # px, long side, for zoom-in
THUMB_Q    = 70       # WebP quality
FULL_Q     = 82
HERE   = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.join(HERE, "loop", "photos")
INDEX  = os.path.join(HERE, "loop", "photos.json")
EXTS   = (".jpg", ".jpeg", ".png")


def slug(name):
    base = os.path.splitext(name)[0].lower()
    base = re.sub(r"[^a-z0-9]+", "-", base).strip("-") or "photo"
    h = hashlib.sha1(name.encode("utf-8")).hexdigest()[:6]
    return f"{base[:40]}-{h}"


def hue_bucket(h):
    deg = h * 360
    if deg < 40 or deg >= 320:        # reds, oranges, pink-red
        return "warm"
    if deg < 70:                      # yellows
        return "warm"
    if deg < 170:                     # greens
        return "green"
    if deg < 255:                     # cyan, blue
        return "cool"
    return "purple"                   # purple, magenta


def analyse_colour(im):
    """Return (hex of the colour that leads the photo, [1-2 colour groups]).
    Picks the colour that really dominates, not a dull background, and lets a
    photo belong to two groups when it has two strong colours."""
    small = im.convert("RGB").resize((64, 64))
    q = small.quantize(colors=16)
    pal = q.getpalette()
    counts = Counter(q.getdata())
    total = sum(counts.values()) or 1

    votes = {b: 0.0 for b in COLOURS}
    best_hex, best_score = None, -1.0
    for idx, n in counts.items():
        r, g, b = pal[idx * 3: idx * 3 + 3]
        share = n / total
        h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
        if s < 0.18 or l < 0.08 or l > 0.95:   # greyish / near black / near white
            votes["neutral"] += share
            score = share * 0.12
        else:
            votes[hue_bucket(h)] += share * s   # weight real colour by how vivid it is
            score = share * s
        if score > best_score:
            best_score, best_hex = score, f"#{r:02x}{g:02x}{b:02x}"

    chroma = {b: v for b, v in votes.items() if b != "neutral"}
    ordered = sorted(chroma.items(), key=lambda kv: -kv[1])
    if ordered[0][1] < 0.06:                     # almost no real colour anywhere
        groups = ["neutral"]
    else:
        groups = [ordered[0][0]]
        if len(ordered) > 1 and ordered[1][1] >= 0.5 * ordered[0][1] and ordered[1][1] >= 0.08:
            groups.append(ordered[1][0])          # a strong second colour
    return best_hex, groups


def save_webp(im, path, long_side, quality):
    w, h = im.size
    k = min(1.0, long_side / max(w, h))
    out = im if k == 1.0 else im.resize((max(1, round(w * k)), max(1, round(h * k))), Image.LANCZOS)
    out.convert("RGB").save(path, "WEBP", quality=quality, method=6)


def main():
    if len(sys.argv) < 2:
        sys.exit("Usage: python3 build.py /path/to/your/originals")
    src = sys.argv[1]
    if not os.path.isdir(src):
        sys.exit(f"Not a folder: {src}")

    os.makedirs(os.path.join(OUTDIR, "thumb"), exist_ok=True)
    os.makedirs(os.path.join(OUTDIR, "full"), exist_ok=True)

    files = sorted(f for f in os.listdir(src) if f.lower().endswith(EXTS))
    print(f"{len(files)} photos found in {src}")

    photos, done, skipped, bad = [], 0, 0, 0
    for i, name in enumerate(files, 1):
        pid = slug(name)
        tpath = os.path.join(OUTDIR, "thumb", pid + ".webp")
        fpath = os.path.join(OUTDIR, "full", pid + ".webp")
        try:
            with Image.open(os.path.join(src, name)) as im:
                im = ImageOps.exif_transpose(im)   # apply rotation, then drop EXIF
                w, h = im.size
                ratio = round(w / h, 4)
                color, cgroups = analyse_colour(im)
                if not (os.path.exists(tpath) and os.path.exists(fpath)):
                    save_webp(im, tpath, THUMB_LONG, THUMB_Q)
                    save_webp(im, fpath, FULL_LONG, FULL_Q)
                    done += 1
                else:
                    skipped += 1
        except Exception as e:
            print(f"  ! skipped {name}: {e}")
            bad += 1
            continue

        photos.append({
            "id": pid,
            "ratio": ratio,
            "color": color,
            "colour": cgroups,
        })
        if i % 50 == 0:
            print(f"  {i}/{len(files)}")

    with open(INDEX, "w", encoding="utf-8") as f:
        json.dump({"colours": COLOURS, "photos": photos}, f,
                  ensure_ascii=False, separators=(",", ":"))

    print(f"\nDone. {len(photos)} photos in index "
          f"({done} built, {skipped} already done, {bad} skipped).")
    print(f"Index written to {INDEX}")


if __name__ == "__main__":
    main()
