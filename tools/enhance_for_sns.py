"""SNS投稿用の画質補正スクリプト.

入力画像に対して以下を行う:
  - EXIF Orientation 反映
  - 軽いノイズ低減 (Median)
  - ホワイトバランス補正 (gray-world)
  - オートコントラスト + 微小ガンマ補正
  - 彩度・明度・シャープネスの軽い強調
  - 長辺 2048px にリサイズ (Instagram/Twitter/Threads でも十分)
  - sRGB に変換して JPEG (quality=92) で保存
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter, ImageOps


def gray_world_white_balance(img: Image.Image) -> Image.Image:
    r, g, b = img.split()[:3]
    r_mean = sum(r.getdata()) / (img.width * img.height)
    g_mean = sum(g.getdata()) / (img.width * img.height)
    b_mean = sum(b.getdata()) / (img.width * img.height)
    gray = (r_mean + g_mean + b_mean) / 3
    r = r.point(lambda v, m=r_mean: min(255, int(v * gray / max(m, 1))))
    g = g.point(lambda v, m=g_mean: min(255, int(v * gray / max(m, 1))))
    b = b.point(lambda v, m=b_mean: min(255, int(v * gray / max(m, 1))))
    return Image.merge("RGB", (r, g, b))


def enhance(src: Path, dst: Path, max_side: int = 2048, quality: int = 92) -> None:
    img = Image.open(src)
    img = ImageOps.exif_transpose(img)
    img = img.convert("RGB")

    img = img.filter(ImageFilter.MedianFilter(size=3))
    img = gray_world_white_balance(img)
    img = ImageOps.autocontrast(img, cutoff=1)

    img = ImageEnhance.Color(img).enhance(1.15)
    img = ImageEnhance.Brightness(img).enhance(1.04)
    img = ImageEnhance.Contrast(img).enhance(1.08)
    img = ImageEnhance.Sharpness(img).enhance(1.4)

    if max(img.size) > max_side:
        ratio = max_side / max(img.size)
        new_size = (int(img.width * ratio), int(img.height * ratio))
        img = img.resize(new_size, Image.LANCZOS)

    dst.parent.mkdir(parents=True, exist_ok=True)
    img.save(dst, "JPEG", quality=quality, optimize=True, progressive=True)
    print(f"saved: {dst}  ({img.width}x{img.height})")


def main() -> int:
    p = argparse.ArgumentParser(description="SNS用 画質補正")
    p.add_argument("src", type=Path)
    p.add_argument("-o", "--out", type=Path, default=None)
    p.add_argument("--max-side", type=int, default=2048)
    p.add_argument("--quality", type=int, default=92)
    args = p.parse_args()

    if not args.src.exists():
        print(f"not found: {args.src}", file=sys.stderr)
        return 1

    dst = args.out or args.src.with_name(f"{args.src.stem}_sns.jpg")
    enhance(args.src, dst, max_side=args.max_side, quality=args.quality)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
