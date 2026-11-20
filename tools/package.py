"""Build dist/Guldbog-<version>.zip from the Guldbog/ addon folder.

Usage: python3 tools/package.py
Every file in Guldbog/ is included, so new files (like Media/) are never forgotten.
"""
import os
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = os.path.join(ROOT, "Guldbog")


def version():
    with open(os.path.join(ADDON, "Guldbog.toc"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("## Version:"):
                return line.split(":", 1)[1].strip()
    sys.exit("No '## Version:' line in Guldbog.toc")


def main():
    out_dir = os.path.join(ROOT, "dist")
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, f"Guldbog-{version()}.zip")
    files = []
    for folder, _, names in os.walk(ADDON):
        for name in names:
            path = os.path.join(folder, name)
            files.append((path, os.path.relpath(path, ROOT).replace(os.sep, "/")))
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for path, arc in sorted(files, key=lambda f: f[1]):
            z.write(path, arc)
    print(out)
    for _, arc in sorted(files, key=lambda f: f[1]):
        print("  " + arc)


if __name__ == "__main__":
    main()
