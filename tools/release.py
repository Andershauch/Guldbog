"""Release helpers used by the GitHub workflow.

  python3 tools/release.py version                # print ## Version (checks CHANGELOG has it)
  python3 tools/release.py check v0.17.1          # tag must match ## Version in Guldbog.toc
  python3 tools/release.py notes 0.17.1           # print that version's CHANGELOG section
  python3 tools/release.py upload dist/Guldbog-0.17.1.zip 0.17.1 [--dry-run]

upload needs CF_API_KEY and CF_PROJECT_ID in the environment. CF_RELEASE_TYPE
(alpha/beta/release, default beta) and CF_GAME_VERSION (default 1.60.1 = Forever)
are optional.
"""
import json
import os
import re
import sys
import urllib.request
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CF_API = os.environ.get("CF_API_URL", "https://wow.curseforge.com/api")


def toc_version():
    with open(os.path.join(ROOT, "Guldbog", "Guldbog.toc"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("## Version:"):
                return line.split(":", 1)[1].strip()
    sys.exit("No '## Version:' line in Guldbog.toc")


def changelog_section(version):
    with open(os.path.join(ROOT, "CHANGELOG.md"), encoding="utf-8") as f:
        text = f.read()
    m = re.search(r"^## " + re.escape(version) + r"\b.*?\n(.*?)(?=^## |\Z)", text, re.M | re.S)
    if not m or not m.group(1).strip():
        sys.exit(f"No CHANGELOG.md section for {version}")
    return m.group(1).strip()


def request(url, token, data=None, content_type=None):
    req = urllib.request.Request(url, data=data, headers={"X-Api-Token": token})
    if content_type:
        req.add_header("Content-Type", content_type)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))


def game_version_id(token, name):
    versions = request(CF_API + "/game/versions", token)
    ids = [v["id"] for v in versions if v.get("name") == name]
    if len(ids) != 1:
        sys.exit(f"Expected exactly one CurseForge game version named {name}, found {len(ids)}")
    return ids[0]


def upload(zip_path, version, dry_run):
    metadata = {
        "changelog": changelog_section(version),
        "changelogType": "markdown",
        "displayName": f"Guldbog {version}",
        "releaseType": os.environ.get("CF_RELEASE_TYPE", "beta"),
    }
    game = os.environ.get("CF_GAME_VERSION", "1.60.1")
    if dry_run:
        print(json.dumps(dict(metadata, gameVersions=[game]), indent=2))
        return
    token, project = os.environ["CF_API_KEY"], os.environ["CF_PROJECT_ID"]
    metadata["gameVersions"] = [game_version_id(token, game)]
    boundary = uuid.uuid4().hex
    with open(zip_path, "rb") as f:
        file_bytes = f.read()
    body = (
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"metadata\"\r\n\r\n"
        f"{json.dumps(metadata)}\r\n"
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; "
        f"filename=\"{os.path.basename(zip_path)}\"\r\nContent-Type: application/zip\r\n\r\n"
    ).encode("utf-8") + file_bytes + f"\r\n--{boundary}--\r\n".encode("utf-8")
    result = request(f"{CF_API}/projects/{project}/upload-file", token, body,
                     f"multipart/form-data; boundary={boundary}")
    print("Uploaded to CurseForge, file id", result.get("id"))


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    cmd = sys.argv[1]
    if cmd == "version":
        version = toc_version()
        changelog_section(version)
        print(version)
    elif len(sys.argv) < 3:
        sys.exit(__doc__)
    elif cmd == "check":
        tag, version = sys.argv[2], toc_version()
        if tag != "v" + version:
            sys.exit(f"Tag {tag} does not match Guldbog.toc version {version}")
        changelog_section(version)
        print(version)
    elif cmd == "notes":
        print(changelog_section(sys.argv[2]))
    elif cmd == "upload":
        upload(sys.argv[2], sys.argv[3], "--dry-run" in sys.argv)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
