#!/usr/bin/env bash
# The web version (Timmy 19 Oct 11:48 "The web version makes a lot of sense"): build it and put it on GitHub Pages,
# https://veriduim.github.io/standoff/ - for iPhones (no APK there) and anyone on a PC. Run it with each release, so the
# web and the APK are the same version (lobbies only match the same version).
#   tools/release_web.sh            build + publish
#   tools/release_web.sh --build    just build (build/web)
# Publishing replaces the gh-pages branch with one commit (the old builds aren't kept - each is ~40 MB).
set -eu
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/c/Users/ajisa/Documents/LocalTools/Godot_v4.7.2-stable_win64_console.exe}"
REPO="Veriduim/standoff"
ver=$(grep -o '"[0-9.]*"' scripts/version.gd | tr -d '"')
rm -rf build/web && mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" build/web/index.html >/dev/null 2>&1 || true
[ -s build/web/index.wasm ] && [ -s build/web/index.pck ] || { echo "WEB BUILD FAILED"; exit 1; }
echo "built web $ver ($(du -sh build/web | cut -f1))"
[ "${1:-}" = "--build" ] && exit 0

pages=build/pages
rm -rf "$pages" && mkdir -p "$pages"
cp build/web/* "$pages/"
rm -f "$pages"/*.import
touch "$pages/.nojekyll"   # (no Jekyll: serve the files as they are)
(
	cd "$pages"
	git init -q -b gh-pages
	git add -A
	git -c user.name="$(git -C ../.. config user.name)" -c user.email="$(git -C ../.. config user.email)" \
		commit -q -m "Web $ver"
	git push -q --force "https://github.com/$REPO.git" gh-pages
)
rm -rf "$pages"
if ! gh api "repos/$REPO/pages" >/dev/null 2>&1; then   # (the first time: switch Pages on for the branch)
	gh api -X POST "repos/$REPO/pages" -f "source[branch]=gh-pages" -f "source[path]=/" >/dev/null 2>&1 || true   # (a gh-pages push can switch it on by itself first - "already enabled")
fi
echo "published web $ver -> https://veriduim.github.io/standoff/ (live in a minute or two)"
