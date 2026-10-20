#!/usr/bin/env bash
# Publish built APKs as GitHub releases (Timmy 21:03: "Why not the apk builds as releases?").
# usage: tools/release_apks.sh <version> <commit> [<version> <commit> ...]
#   each version: tag v<version> on <commit>, notes = the commit that bumped to it, build/Standoff-<version>.apk attached.
#   A version that already has a release is skipped.
set -u
cd "$(dirname "$0")/.."
while [ $# -ge 2 ]; do
	v="$1"; c="$2"; shift 2
	apk="build/Standoff-$v.apk"
	if gh release view "v$v" >/dev/null 2>&1; then echo "skip v$v (already released)"; continue; fi
	[ -f "$apk" ] || { echo "MISSING $apk"; continue; }
	sha=$(git rev-parse "$c")
	bump=$(git log --format=%h -S "config/version=\"$v\"" --reverse -- project.godot | head -1)
	notes="$(git log -1 --format=%B "${bump:-$c}" | grep -v '^Co-Authored-By\|^Claude-Session')

Android debug build (install the APK on the phone; it updates the one already there)."
	# (a copy named Standoff.apk too: .../releases/latest/download/Standoff.apk is always the newest - 20 Oct 17:50
	# "is this on GitHub and possible to download public?")
	same="$(dirname "$apk")/Standoff.apk"
	cp "$apk" "$same"
	gh release create "v$v" "$apk" "$same" --target "$sha" --title "Standoff $v" --notes "$notes" >/dev/null \
		&& echo "released v$v ($c)" || echo "FAILED v$v"
done
