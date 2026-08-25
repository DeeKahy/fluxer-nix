#!/usr/bin/env python3
"""Render the upstream commits between two canary builds as a collapsed section.

Upstream tags every canary build as fluxer-desktop-canary@<version> in the
fluxerapp/fluxer monorepo, so the range between two pinned versions is exact.
The AppImage only carries the Electron shell (the client itself is loaded from
canary.fluxer.app at runtime), so commits are filtered to the paths that
actually end up in the package. Repo-wide that range is an order of magnitude
noisier and mostly irrelevant here.

Prints markdown to stdout. Never exits non-zero: a changelog is a nice-to-have
and must not fail a bump that is otherwise good.
"""

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

REPO = "fluxerapp/fluxer"
TAG_PREFIX = "fluxer-desktop-canary@"
PATHS = ["fluxer_desktop", "packages/voice_engine_v2"]
MAX_COMMITS = 100


def api(endpoint, **params):
    url = f"https://api.github.com/repos/{REPO}/{endpoint}"
    if params:
        url += "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json"})
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def version_key(v):
    return tuple(int(part) for part in v.split("."))


def matching_tags():
    """Every canary tag, newest first. One page holds well over a year of them."""
    out = {}
    for page in range(1, 6):
        refs = api("git/matching-refs/tags/" + TAG_PREFIX, per_page=100, page=page)
        if not refs:
            break
        for ref in refs:
            name = ref["ref"].rsplit("/", 1)[-1]
            version = name[len(TAG_PREFIX):]
            try:
                version_key(version)
            except ValueError:
                continue
            out[version] = ref["object"]["sha"]
    return out


def resolve(tags, version):
    """The tag for this version, or the nearest usable one.

    Upstream keeps only a couple of weeks of canary tags and does not tag every
    published build, so an exact miss falls back to the closest earlier tag,
    and a version older than every surviving tag falls back to the oldest one
    still there. Both cases are reported so the range is not read as exact.
    """
    if version in tags:
        return version, tags[version], "exact"
    if not tags:
        return None, None, "none"
    target = version_key(version)
    earlier = [v for v in tags if version_key(v) <= target]
    if earlier:
        closest = max(earlier, key=version_key)
        return closest, tags[closest], "earlier"
    oldest = min(tags, key=version_key)
    return oldest, tags[oldest], "oldest"


def commits_for(sha, path, since, until):
    out = []
    for page in range(1, 6):
        batch = api("commits", sha=sha, path=path, since=since, until=until,
                    per_page=100, page=page)
        out.extend(batch)
        if len(batch) < 100:
            break
    return out


def render(old_version, new_version):
    tags = matching_tags()
    old_tag, old_sha, old_kind = resolve(tags, old_version)
    new_tag, new_sha, new_kind = resolve(tags, new_version)

    if not old_sha or not new_sha:
        return (f"<details>\n<summary>Upstream changes</summary>\n\n"
                f"No `{TAG_PREFIX}` tags found on `{REPO}`, so the range could "
                f"not be worked out. "
                f"[Tags](https://github.com/{REPO}/tags)\n\n</details>")

    caveats = []
    for version, tag, kind in ((old_version, old_tag, old_kind),
                               (new_version, new_tag, new_kind)):
        if kind == "earlier":
            caveats.append(f"`{version}` is not tagged upstream; using the closest "
                           f"earlier tag, `{tag}`")
        elif kind == "oldest":
            caveats.append(f"`{version}` is older than every surviving upstream tag "
                           f"(they get pruned); measuring from the oldest one left, "
                           f"`{tag}`, so earlier changes are missing")

    if old_sha == new_sha:
        return ("<details>\n<summary>Upstream changes</summary>\n\n"
                "Both builds point at the same upstream commit.\n\n</details>")

    since = api(f"commits/{old_sha}")["commit"]["committer"]["date"]
    until = api(f"commits/{new_sha}")["commit"]["committer"]["date"]

    seen = {}
    for path in PATHS:
        for c in commits_for(new_sha, path, since, until):
            seen[c["sha"]] = c
    commits = sorted(seen.values(),
                     key=lambda c: c["commit"]["committer"]["date"], reverse=True)

    compare = (f"https://github.com/{REPO}/compare/"
               f"{TAG_PREFIX}{old_tag}...{TAG_PREFIX}{new_tag}")

    lines = []
    if not commits:
        lines.append("Nothing in this range touched the packaged desktop client. "
                     "Upstream cuts a build per push across the whole monorepo, so "
                     "this happens.")
    else:
        shown = commits[:MAX_COMMITS]
        for c in shown:
            subject = c["commit"]["message"].split("\n")[0].strip()
            subject = subject.replace("|", "\\|")
            short = c["sha"][:7]
            lines.append(f"- [`{short}`](https://github.com/{REPO}/commit/{c['sha']}) {subject}")
        if len(commits) > len(shown):
            lines.append(f"- ...and {len(commits) - len(shown)} more")

    n = len(commits)
    summary = (f"Upstream changes to the desktop client "
               f"({n} commit{'' if n == 1 else 's'})")

    out = ["<details>", f"<summary>{summary}</summary>", ""]
    out.extend(lines)
    out.append("")
    out.append(f"Filtered to {', '.join('`%s`' % p for p in PATHS)}. "
               f"[Full diff across the monorepo]({compare})")
    for caveat in caveats:
        out.append("")
        out.append(f"> {caveat}")
    out.append("")
    out.append("</details>")
    return "\n".join(out)


def main():
    if len(sys.argv) != 3:
        print("usage: changelog.py OLD_VERSION NEW_VERSION", file=sys.stderr)
        return
    old_version, new_version = sys.argv[1], sys.argv[2]
    try:
        print(render(old_version, new_version))
    except (urllib.error.URLError, urllib.error.HTTPError, KeyError, ValueError) as e:
        print(f"<details>\n<summary>Upstream changes</summary>\n\n"
              f"Could not read the changelog from `{REPO}`: `{e}`\n\n</details>")


if __name__ == "__main__":
    main()
