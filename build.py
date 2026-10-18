#!/usr/bin/env python3
"""
build.py — prepare photos for the Loop page.

What it does, per photo in the source folder:
  - fixes orientation and strips EXIF (removes GPS and other personal data)
  - writes a small thumbnail and a large version, both WebP
  - records aspect ratio and dominant colour
It then writes photos.json, the index the Loop page reads.
Tags come from tags.json (see the Goose instructions); a photo with no
matching category goes to "misc". Re-runs only process new photos.

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
CATEGORIES = ["architecture", "landscape", "people", "car", "animal", "objects"]  # misc is implicit
COLOURS = ["warm", "green", "cool", "purple", "neutral"]
THUMB_LONG = 240      # px, long side, for the far view
FULL_LONG  = 1600     # px, long side, for zoom-in
THUMB_Q    = 70       # WebP quality
FULL_Q     = 82
HERE   = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.join(HERE, "loop", "photos")
INDEX  = os.path.join(HERE, "loop", "photos.json")
TAGS   = os.path.join(HERE, "tags.json")
EXTS   = (".jpg", ".jpeg", ".png")


def slug(name):
    base = os.path.splitext(name)[0].lower()
    base = re.sub(r"[^a-z0-9]+", "-", base).strip("-") or "photo"
    h = hashlib.sha1(name.encode("utf-8")).hexdigest()[:6]
    return f"{base[:40]}-{h}"


def dominant_color(im):
    small = im.convert("RGB").resize((48, 48))
    q = small.quantize(colors=8)
    pal = q.getpalette()
    counts = Counter(q.getdata())
    idx = counts.most_common(1)[0][0]
    r, g, b = pal[idx * 3: idx * 3 + 3]
    return (r, g, b), f"#{r:02x}{g:02x}{b:02x}"


def colour_group(rgb):
    r, g, b = (c / 255 for c in rgb)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    if s < 0.18:                      # little colour → black/white/grey
        return "neutral"
    deg = h * 360
    if deg < 40 or deg >= 320:        # reds, oranges
        return "warm"
    if deg < 70:                      # yellows / warm
        return "warm"
    if deg < 170:                     # greens
        return "green"
    if deg < 255:                     # cyan / blue
        return "cool"
    return "purple"                   # purple / pink / magenta


def save_webp(im, path, long_side, quality):
    w, h = im.size
    k = min(1.0, long_side / max(w, h))
    out = im if k == 1.0 else im.resize((max(1, round(w * k)), max(1, round(h * k))), Image.LANCZOS)
    out.convert("RGB").save(path, "WEBP", quality=quality, method=6)


def load_tags():
    if not os.path.exists(TAGS):
        return {}
    try:
        with open(TAGS, encoding="utf-8") as f:
            raw = json.load(f)
    except Exception as e:
        print(f"  ! tags.json could not be read ({e}); continuing without tags")
        return {}
    clean = {}
    for name, tags in raw.items():
        if not isinstance(tags, list):
            continue
        keep = [t.lower() for t in tags if t.lower() in CATEGORIES]
        clean[name] = keep
    return clean


def main():
    if len(sys.argv) < 2:
        sys.exit("Usage: python3 build.py /path/to/your/originals")
    src = sys.argv[1]
    if not os.path.isdir(src):
        sys.exit(f"Not a folder: {src}")

    os.makedirs(os.path.join(OUTDIR, "thumb"), exist_ok=True)
    os.makedirs(os.path.join(OUTDIR, "full"), exist_ok=True)
    tags = load_tags()

    files = sorted(f for f in os.listdir(src) if f.lower().endswith(EXTS))
    print(f"{len(files)} photos found in {src}")
    if tags:
        print(f"tags.json loaded: {len(tags)} entries")
    else:
        print("no tags.json yet — every photo will be 'misc' for now")

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
                rgb, color = dominant_color(im)
                cgroup = colour_group(rgb)
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

        cats = tags.get(name, [])
        photos.append({
            "id": pid,
            "ratio": ratio,
            "color": color,
            "colour": cgroup,
            "tags": cats if cats else ["misc"],
        })
        if i % 50 == 0:
            print(f"  {i}/{len(files)}")

    with open(INDEX, "w", encoding="utf-8") as f:
        json.dump({"categories": CATEGORIES + ["misc"], "colours": COLOURS,
                   "photos": photos}, f,
                  ensure_ascii=False, separators=(",", ":"))

    tagged = sum(1 for p in photos if p["tags"] != ["misc"])
    print(f"\nDone. {len(photos)} photos in index "
          f"({done} built, {skipped} already done, {bad} skipped).")
    print(f"{tagged} tagged, {len(photos) - tagged} in misc.")
    print(f"Index written to {INDEX}")


if __name__ == "__main__":
    main()
