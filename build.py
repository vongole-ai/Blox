#!/usr/bin/env python3
"""
build.py — prepare photos for the Loop page.

Per photo in the source folder (.jpg / .jpeg / .png):
  - names it by a fingerprint of its content, so public URLs reveal nothing
    about the original file name (and identical copies are published once)
  - fixes orientation, converts colour to sRGB, drops ALL metadata (GPS,
    camera, dates) and writes three WebP versions: thumb (240 px), mid (800 px)
    and full (1600 px), so the page only loads the size it needs
  - records aspect ratio and colour groups (for the Colour filter)
Then writes loop/photos.json safely (never half-written).

Re-runs only convert photos that are new or have changed; it reads the
existing thumbnails for everything else, so a re-run takes seconds.

Usage:
  pip install pillow
  python3 build.py /path/to/your/originals            # build
  python3 build.py /path/to/your/originals --prune    # build, then DELETE web
                                                      # files no longer used
Without --prune nothing is ever deleted; it only tells you how many unused
web files there are.
"""

import sys, os, io, json, hashlib, colorsys
from collections import Counter
from PIL import Image, ImageOps

try:
    from PIL import ImageCms
    SRGB = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB"))
except Exception:            # LittleCMS not available: keep colours as they are
    ImageCms, SRGB = None, None

# ---- settings ----
COLOURS    = ["warm", "green", "cool", "purple", "neutral"]
SIZES      = {        # name: (long side in px, WebP quality)
    "thumb": (240, 70),     # far view
    "mid":   (800, 78),     # middle distance
    "full":  (1600, 82),    # one photo on screen, slideshow
}
FULL_LONG  = SIZES["full"][0]
BG         = (17, 17, 16)   # page background, used behind transparent PNGs
HERE   = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.join(HERE, "loop", "photos")
INDEX  = os.path.join(HERE, "loop", "photos.json")
EXTS   = (".jpg", ".jpeg", ".png")


# ---------- helpers ----------
def content_id(data):
    """16 hex chars from the file's bytes: stable across renames, reveals nothing."""
    return hashlib.sha256(data).hexdigest()[:16]


def flatten(im):
    """Any mode -> RGB. Transparent PNGs go on the page background instead of black."""
    if im.mode in ("RGBA", "LA", "PA") or (im.mode == "P" and "transparency" in im.info):
        im = im.convert("RGBA")
        base = Image.new("RGB", im.size, BG)
        base.paste(im, mask=im.split()[-1])
        return base
    return im.convert("RGB")


def to_srgb(im, icc):
    """Convert an embedded colour profile (e.g. iPhone Display P3) to sRGB."""
    if not icc or ImageCms is None:
        return im
    try:
        src = ImageCms.ImageCmsProfile(io.BytesIO(icc))
        out = ImageCms.profileToProfile(im, src, SRGB, outputMode="RGB")
        return out if out is not None else im
    except Exception:     # unusual or broken profile: keep the pixels as they are
        return im


def save_webp(im, path, long_side, quality):
    w, h = im.size
    k = min(1.0, long_side / max(w, h))
    out = im if k == 1.0 else im.resize((max(1, round(w * k)), max(1, round(h * k))), Image.LANCZOS)
    clean = Image.new("RGB", out.size)          # fresh image: carries no metadata at all
    clean.paste(out.convert("RGB"))
    tmp = path + ".tmp"
    clean.save(tmp, "WEBP", quality=quality, method=6, exif=b"")
    os.replace(tmp, path)


def hue_bucket(h):
    deg = h * 360
    if deg < 70 or deg >= 320:   # reds, oranges, yellows
        return "warm"
    if deg < 170:
        return "green"
    if deg < 255:
        return "cool"
    return "purple"


def analyse_colour(im):
    """(hex of the colour that leads the photo, [1-2 colour groups])."""
    small = im.convert("RGB").resize((64, 64))
    q = small.quantize(colors=16)
    pal = q.getpalette()
    pixels = q.get_flattened_data() if hasattr(q, "get_flattened_data") else q.getdata()
    counts = Counter(pixels)
    total = sum(counts.values()) or 1
    votes = {b: 0.0 for b in COLOURS}
    best_hex, best_score = "#444444", -1.0
    for idx, n in counts.items():
        r, g, b = pal[idx * 3: idx * 3 + 3]
        share = n / total
        h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
        if s < 0.18 or l < 0.08 or l > 0.95:
            votes["neutral"] += share
            score = share * 0.12
        else:
            votes[hue_bucket(h)] += share * s
            score = share * s
        if score > best_score:
            best_score, best_hex = score, f"#{r:02x}{g:02x}{b:02x}"
    ordered = sorted(((b, v) for b, v in votes.items() if b != "neutral"), key=lambda kv: -kv[1])
    if ordered[0][1] < 0.06:
        return best_hex, ["neutral"]
    groups = [ordered[0][0]]
    if ordered[1][1] >= 0.5 * ordered[0][1] and ordered[1][1] >= 0.08:
        groups.append(ordered[1][0])
    return best_hex, groups


def convert(data, paths):
    """Decode an original and write its web versions (largest first)."""
    with Image.open(io.BytesIO(data)) as im:
        if im.format == "JPEG":
            im.draft("RGB", (FULL_LONG, FULL_LONG))   # decode big JPEGs at reduced size: much faster
        icc = im.info.get("icc_profile")
        im = ImageOps.exif_transpose(im)
        im = to_srgb(flatten(im), icc)
        for name in ("full", "mid", "thumb"):
            long_side, quality = SIZES[name]
            save_webp(im, paths[name], long_side, quality)


def write_index(photos):
    tmp = INDEX + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump({"colours": COLOURS, "photos": photos}, f, ensure_ascii=False, separators=(",", ":"))
    os.replace(tmp, INDEX)   # atomic: the site never sees a half-written file


# ---------- main ----------
def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    prune = "--prune" in sys.argv
    if not args:
        sys.exit("Usage: python3 build.py /path/to/your/originals [--prune]")
    src = os.path.expanduser(args[0])
    if not os.path.isdir(src):
        sys.exit(f"Not a folder: {src}")

    dirs = {name: os.path.join(OUTDIR, name) for name in SIZES}
    for d in dirs.values():
        os.makedirs(d, exist_ok=True)

    files = sorted(f for f in os.listdir(src) if f.lower().endswith(EXTS) and not f.startswith("."))
    print(f"{len(files)} photos found in {src}")

    photos, seen = [], set()
    built = reused = dupes = bad = 0
    for i, name in enumerate(files, 1):
        try:
            with open(os.path.join(src, name), "rb") as fh:
                data = fh.read()
            pid = content_id(data)
            if pid in seen:
                dupes += 1
                continue
            paths = {name: os.path.join(d, pid + ".webp") for name, d in dirs.items()}
            if all(os.path.exists(p) for p in paths.values()):
                reused += 1
            else:
                convert(data, paths)
                built += 1
            with Image.open(paths["full"]) as full:
                w, h = full.size                  # header only, no decoding
            with Image.open(paths["thumb"]) as thumb:
                color, groups = analyse_colour(thumb)
        except Exception as e:
            reason = "not a readable image" if "cannot identify" in str(e) else str(e)
            print(f"  ! skipped {name}: {reason}")
            bad += 1
            continue
        seen.add(pid)
        photos.append({"id": pid, "ratio": round(w / h, 4), "color": color, "colour": groups})
        if i % 50 == 0:
            print(f"  {i}/{len(files)}")

    write_index(photos)

    # unused web files (old names, deleted or edited photos)
    used = {p["id"] + ".webp" for p in photos}
    unused = [os.path.join(d, f) for d in dirs.values() for f in os.listdir(d)
              if f.endswith(".webp") and f not in used]
    if prune and unused:
        for p in unused:
            os.remove(p)

    print(f"\nDone. {len(photos)} photos in index "
          f"({built} converted, {reused} already done, {dupes} duplicates skipped, {bad} failed).")
    if unused:
        if prune:
            print(f"Deleted {len(unused)} unused web files.")
        else:
            print(f"{len(unused)} unused web files in loop/photos. Run again with --prune to delete them.")
    print(f"Index written to {INDEX}")


if __name__ == "__main__":
    main()
