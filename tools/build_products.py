#!/usr/bin/env python3
"""Render standalone products from shared templates; never deploy or publish."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PRODUCTS = ("revival", "forever")


def product_files(product: str, with_data: bool = False) -> tuple[str, dict[Path, bytes]]:
    definition = ROOT / "products" / product
    config = json.loads((definition / "product.json").read_text())
    addon_id = config["addonId"]
    replacements = {
        "ADDON_ID": addon_id,
        "DISPLAY_NAME": config["displayName"],
        "COMMAND_KEY": config["commandKey"],
        "LONG_COMMAND": config["longCommand"],
        "SHORT_COMMAND": config["shortCommand"],
        "VERSION": config["version"],
        "FEEDBACK_URL": config["feedbackUrl"],
        "STATUS_TEXT": config["statusText"],
        "CLIENT_FLAVOR_IMPLEMENTATION": (ROOT / "compat" / (product + ".lua")).read_text().rstrip(),
    }

    def render(path: Path) -> bytes:
        text = path.read_text()
        for key, value in replacements.items():
            text = text.replace("__" + key + "__", value)
        if re.search(r"__[A-Z_]+__", text):
            raise ValueError(f"Unresolved product token in {path}")
        return text.encode()

    files = {path.relative_to(ROOT / "shared"): render(path)
             for path in sorted((ROOT / "shared").rglob("*")) if path.is_file()}
    for path in sorted(definition.glob("*.toc")):
        files[Path(path.name)] = render(path)
    if with_data:
        # Research sources and their validators are intentionally local, as before.
        from generate_data import generated_files, load_datasets
        from generate_forever import generated_forever_files
        data_files = generated_files(load_datasets()) if product == "revival" else generated_forever_files()
        for path, text in data_files.items():
            files[path.relative_to(ROOT / addon_id)] = text.encode()
    else:
        for path in sorted((ROOT / addon_id / "Data").rglob("*.lua")):
            files[path.relative_to(ROOT / addon_id)] = path.read_bytes()
    # Existing Revival artwork is kept byte-for-byte; both products use these controls.
    for name in ("boss-marker.tga", "boss-marker-ring.tga", "dropdown-chevron.tga"):
        files[Path("assets") / name] = (ROOT / "shared-assets" / name).read_bytes()
    icon = definition / "assets/minimap-icon.tga"
    files[Path("assets/minimap-icon.tga")] = icon.read_bytes()
    for name in ("LICENSE", "THIRD_PARTY_NOTICES.md"):
        files[Path(name)] = (ROOT / name).read_bytes()
    for path, data in list(files.items()):
        if path.suffix == ".toc":
            for line in data.decode().splitlines():
                if line and not line.startswith("##") and Path(line.replace("\\", "/")) not in files:
                    raise ValueError(f"Missing {addon_id} TOC file: {line}")
    return addon_id, files


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--product", choices=(*PRODUCTS, "all"), default="all")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--with-data", action="store_true", help="also regenerate/check data from local research JSON")
    parser.add_argument("--package", action="store_true", help="write a local ZIP under dist/")
    parser.add_argument("--interface", type=int, help="verified Forever interface for a local package")
    args = parser.parse_args()
    if args.check and args.package:
        parser.error("--check and --package are mutually exclusive")
    if args.interface is not None and (not args.package or args.product != "forever" or args.interface <= 0):
        parser.error("--interface requires --product forever --package and a positive interface")
    if args.package and args.product in ("all", "forever") and not args.interface:
        parser.error("Forever packaging requires --product forever --interface from a verified client")
    stale = []
    for product in PRODUCTS if args.product == "all" else (args.product,):
        addon_id, files = product_files(product, with_data=args.with_data)
        for relative, data in files.items():
            target = ROOT / addon_id / relative
            if args.check:
                if not target.is_file() or target.read_bytes() != data:
                    stale.append(str(target.relative_to(ROOT)))
            elif not args.package:
                target.parent.mkdir(parents=True, exist_ok=True)
                if not target.is_file() or target.read_bytes() != data:
                    target.write_bytes(data)
        if args.package:
            config = json.loads((ROOT / "products" / product / "product.json").read_text())
            output = ROOT / "dist" / f"{addon_id}-{config['version']}.zip"
            output.parent.mkdir(exist_ok=True)
            with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
                for relative, data in sorted(files.items()):
                    if product == "forever" and relative.suffix == ".toc":
                        data = data.replace(b"## Interface: 0\n", f"## Interface: {args.interface}\n".encode())
                    archive.writestr(f"{addon_id}/{relative.as_posix()}", data)
            print(f"Local package: {output.relative_to(ROOT)}")
    if stale:
        print("Stale product files: " + ", ".join(stale))
        return 1
    print("Product outputs verified." if args.check else "Product build complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
