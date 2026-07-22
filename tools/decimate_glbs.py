#!/usr/bin/env python3
"""Batch-decimate oversized GLB meshes with gltf-transform (meshoptimizer).

Usage:
  python3 tools/decimate_glbs.py              # dry-run (report only)
  python3 tools/decimate_glbs.py --apply      # backup + rewrite in place
  python3 tools/decimate_glbs.py --apply --target-verts 8000

  # Buildings look bad after aggressive simplify — redo gently from originals:
  python3 tools/decimate_glbs.py --apply --only buildings --from-backup \\
      --target-verts 40000 --error 0.01 --min-mb 0
"""

from __future__ import annotations

import argparse
import json
import shutil
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets" / "models"
BACKUP = ROOT / "assets" / "models" / "_glb_originals"
MIN_SIZE_MB = 2.0
DEFAULT_TARGET_VERTS = 8_000
SKIP_NAMES = {
    # Already tiny / intentionally detailed — leave alone unless huge
}


def parse_glb(path: Path) -> tuple[dict, int]:
    data = path.read_bytes()
    magic, _version, _length = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67:
        raise ValueError(f"Not a GLB: {path}")
    offset = 12
    chunks: dict[int, bytes] = {}
    while offset + 8 <= len(data):
        chunk_len, chunk_type = struct.unpack_from("<II", data, offset)
        offset += 8
        chunks[chunk_type] = data[offset : offset + chunk_len]
        offset += chunk_len
    js = json.loads(chunks[0x4E4F534A].decode("utf-8"))
    return js, len(data)


def max_position_verts(js: dict) -> int:
    """Best-effort vertex count from largest VEC3 float accessor (pos/normal)."""
    best = 0
    for accessor in js.get("accessors", []):
        if accessor.get("type") == "VEC3" and accessor.get("componentType") == 5126:
            best = max(best, int(accessor.get("count", 0)))
    return best


def find_gltf_transform() -> list[str]:
    """Return argv prefix to run gltf-transform CLI."""
    local = shutil.which("gltf-transform")
    if local:
        return [local]
    npx = shutil.which("npx")
    if npx:
        return [npx, "--yes", "@gltf-transform/cli"]
    raise SystemExit(
        "Need Node.js + gltf-transform.\n"
        "  brew install node\n"
        "  npm install -g @gltf-transform/cli\n"
        "Or ensure `npx` is on PATH."
    )


def matches_only(rel: Path, only: str | None) -> bool:
    if not only:
        return True
    return rel.as_posix().startswith(only.strip("/"))


def collect_targets(min_mb: float, only: str | None, from_backup: bool) -> list[tuple[Path, Path]]:
    """Return (source_path, dest_path) pairs. source may be backup when --from-backup."""
    root = BACKUP if from_backup else ASSETS
    if from_backup and not BACKUP.exists():
        raise SystemExit(f"No backup at {BACKUP}; run once without --from-backup first.")
    pairs: list[tuple[Path, Path]] = []
    for path in sorted(root.rglob("*.glb")):
        if not from_backup and "_glb_originals" in path.parts:
            continue
        rel = path.relative_to(root)
        if not matches_only(rel, only):
            continue
        if path.name.lower() in SKIP_NAMES:
            continue
        # Size gate uses original/source size
        if path.stat().st_size < min_mb * 1024 * 1024:
            continue
        dest = ASSETS / rel
        pairs.append((path, dest))
    return pairs


def ratio_for(verts: int, target: int) -> float:
    if verts <= 0:
        return 0.05
    # Keep a floor so meshoptimizer still has something to do on mid-size files
    return max(0.005, min(1.0, target / verts))


def run_simplify(
    cli: list[str],
    src: Path,
    dst: Path,
    ratio: float,
    error: float,
    tmp: Path,
    lock_border: bool,
) -> None:
    # Weld first so split vertices don't block meshoptimizer.
    welded = tmp / f"welded_{src.name}"
    subprocess.run([*cli, "weld", str(src), str(welded)], check=True)
    cmd = [
        *cli,
        "simplify",
        str(welded),
        str(dst),
        "--ratio",
        f"{ratio:.6f}",
        "--error",
        f"{error:.6f}",
    ]
    if lock_border:
        cmd.extend(["--lock-border", "true"])
    subprocess.run(cmd, check=True)
    welded.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(description="Decimate large farm GLBs for mobile export size.")
    parser.add_argument("--apply", action="store_true", help="Write simplified GLBs (backs up originals first).")
    parser.add_argument("--target-verts", type=int, default=DEFAULT_TARGET_VERTS)
    parser.add_argument("--min-mb", type=float, default=MIN_SIZE_MB, help="Only process GLBs at least this large.")
    parser.add_argument(
        "--error",
        type=float,
        default=0.05,
        help="Simplification error tolerance (fraction of mesh radius). Higher = more reduction / uglier.",
    )
    parser.add_argument("--only", type=str, default=None, help="Only process a subfolder, e.g. buildings")
    parser.add_argument(
        "--from-backup",
        action="store_true",
        help="Always simplify from _glb_originals (needed to re-run with gentler settings).",
    )
    parser.add_argument(
        "--lock-border",
        action="store_true",
        help="Preserve mesh borders better (often helps buildings).",
    )
    parser.add_argument("--restore", action="store_true", help="Restore GLBs from _glb_originals backup.")
    args = parser.parse_args()

    if args.restore:
        if not BACKUP.exists():
            print(f"No backup at {BACKUP}")
            return 1
        count = 0
        for bak in BACKUP.rglob("*.glb"):
            rel = bak.relative_to(BACKUP)
            if not matches_only(rel, args.only):
                continue
            dest = ASSETS / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(bak, dest)
            count += 1
            print(f"restored  {rel}")
        print(f"Restored {count} files.")
        return 0

    targets = collect_targets(args.min_mb, args.only, args.from_backup)
    if not targets:
        print("No matching GLBs found.")
        return 0

    print(f"{'MB':>7} {'verts~':>8} {'ratio':>7}  path")
    plan: list[tuple[Path, Path, int, float]] = []
    for src, dest in targets:
        js, size = parse_glb(src)
        verts = max_position_verts(js)
        ratio = ratio_for(verts, args.target_verts)
        plan.append((src, dest, verts, ratio))
        print(f"{size/(1024*1024):7.1f} {verts:8d} {ratio:7.3f}  {dest.relative_to(ROOT)}")

    total_before = sum(src.stat().st_size for src, *_ in plan)
    print(f"\n{len(plan)} files, {total_before/1024/1024:.1f} MB source total")
    print(f"Target ~{args.target_verts} verts/model, error={args.error}")

    if not args.apply:
        print("\nDry-run only. Re-run with --apply to backup + rewrite.")
        return 0

    cli = find_gltf_transform()
    subprocess.run([*cli, "--version"], check=True, capture_output=True)

    BACKUP.mkdir(parents=True, exist_ok=True)
    tmp_dir = ROOT / "tools" / ".decimate_tmp"
    tmp_dir.mkdir(parents=True, exist_ok=True)

    ok = 0
    for src, dest, verts, ratio in plan:
        rel = dest.relative_to(ASSETS)
        bak = BACKUP / rel
        bak.parent.mkdir(parents=True, exist_ok=True)
        # Prefer keeping the first true original forever.
        if not bak.exists():
            shutil.copy2(src if src != bak else dest, bak)
            print(f"backup   {rel}")
        else:
            print(f"backup   {rel} (already exists, keeping first backup)")

        out = tmp_dir / dest.name
        try:
            run_simplify(cli, src, out, ratio, args.error, tmp_dir, args.lock_border)
        except subprocess.CalledProcessError as exc:
            print(f"FAIL     {rel}: {exc}", file=sys.stderr)
            continue

        dest.parent.mkdir(parents=True, exist_ok=True)
        before = src.stat().st_size
        shutil.move(str(out), str(dest))
        after = dest.stat().st_size
        try:
            js2, _ = parse_glb(dest)
            verts2 = max_position_verts(js2)
        except Exception:
            verts2 = -1
        print(
            f"done     {rel}: {before/1024/1024:.1f}MB → {after/1024/1024:.1f}MB"
            f"  verts {verts} → {verts2}"
        )
        ok += 1

    shutil.rmtree(tmp_dir, ignore_errors=True)

    total_after = sum(dest.stat().st_size for _, dest, *_ in plan)
    print(f"\nSimplified {ok}/{len(plan)}")
    print(f"Size: {total_before/1024/1024:.1f} MB → {total_after/1024/1024:.1f} MB")
    print(f"Originals kept in: {BACKUP.relative_to(ROOT)}")
    print("Next: open Godot so assets reimport, then check in-game.")
    return 0 if ok == len(plan) else 1


if __name__ == "__main__":
    raise SystemExit(main())
