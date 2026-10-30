#!/usr/bin/env bash
# Checks your releases, level by level.
#
#   ./check.sh <github-user> <repo-name> <folder-of-your-repo>
#
# Example:
#   ./check.sh tigran my-site ~/my-site
#
# It looks at THREE places:
#   - your live site          https://<github-user>.github.io/<repo-name>/
#   - GitHub (public data)    your tags, your releases, your pipeline runs. Your repository must be PUBLIC.
#   - your computer           the pipeline files and the git history in <folder-of-your-repo>
#
# Your site needs a minute or two to update after a push. If a check fails right after a push, wait and run again.
# Optional bonus: CUSTOM_DOMAIN=www.example.com ./check.sh ...
# PROVIDED FILE - do not change.

set -u

GH_USER_NAME="${1:-${GH_USER:-}}"
GH_REPO_NAME="${2:-${GH_REPO:-}}"
GH_FOLDER="${3:-${GH_DIR:-}}"

if [ -z "$GH_USER_NAME" ] || [ -z "$GH_REPO_NAME" ] || [ -z "$GH_FOLDER" ]; then
    echo "Usage: ./check.sh <github-user> <repo-name> <folder-of-your-repo>"
    echo "Example: ./check.sh tigran my-site ~/my-site"
    exit 2
fi
if [ ! -d "$GH_FOLDER" ]; then
    echo "The folder $GH_FOLDER does not exist."
    exit 2
fi
for tool in curl git sort; do
    command -v "$tool" >/dev/null 2>&1 || { echo "The tool '$tool' is not installed."; exit 2; }
done

# These three can be changed only for tests of this script.
API="${API_BASE:-https://api.github.com}"
PAGES="${PAGES_BASE:-https://$GH_USER_NAME.github.io}"
RAW="${RAW_BASE:-https://raw.githubusercontent.com}"

SITE="$PAGES/$GH_REPO_NAME"
STATE="$(cd "$(dirname "$0")" && pwd)/.state-$GH_USER_NAME-$GH_REPO_NAME"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASSED=0
FAILED=0
SKIPPED=0
LEVEL_FAILED=0

pass() { echo "  PASS  $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  FAIL  $1"; FAILED=$((FAILED + 1)); LEVEL_FAILED=1; }
skip() { echo "  SKIP  $1"; SKIPPED=$((SKIPPED + 1)); }
hint() { echo "        -> $1"; }
title() { echo; echo "== $1"; LEVEL_FAILED=0; }

# ---------------------------------------------------------------- helpers

# http_code <url>: the HTTP status of a page ("000" when nothing answers)
http_code() {
    curl -s -L -o /dev/null -w '%{http_code}' --max-time 15 -H 'Cache-Control: no-cache' "$1" 2>/dev/null
}

# fetch <url>: the text of a page (a fresh copy: "?t=" gives a new address every time)
fetch() {
    local url="$1" sep='?'
    case "$url" in *\?*) sep='&' ;; esac
    curl -s -L --max-time 15 -H 'Cache-Control: no-cache' "$url${sep}t=$(date +%s)" 2>/dev/null
}

# json_version <text>: the value of "version" in a small JSON text, or nothing
json_version() {
    echo "$1" | tr -d '\n\r' | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1
}

is_semver() { echo "$1" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; }

# newer <a> <b>: true when version a is bigger than version b
newer() {
    [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n 1)" = "$1" ]
}

# the live version of the site
live_version() { json_version "$(fetch "$SITE/version.json")"; }

# the pipeline file without the comment lines
code_of() {
    grep -v '^[[:space:]]*#' "$1" 2>/dev/null | sed 's/[[:space:]]#.*$//'
}

# has_all <file> <text>...: the file (without comments) contains every text
missing_in() {
    local file="$1" text
    shift
    for text in "$@"; do
        code_of "$file" | grep -Fq -- "$text" || { echo "$text"; return; }
    done
}

# the tags of your published releases, the newest first
release_tags() {
    fetch "$API/repos/$GH_USER_NAME/$GH_REPO_NAME/releases?per_page=30" \
        | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/'
}

# release_json <tag>: the JSON of one release, saved in a file. Returns 1 when there is none.
release_json() {
    local file="$WORK/release-$1.json"
    [ -s "$file" ] || fetch "$API/repos/$GH_USER_NAME/$GH_REPO_NAME/releases/tags/$1" >"$file"
    grep -q '"tag_name"' "$file"
}

# who made the release: the first "login" of the release (its author)
release_author() {
    grep -m1 '"login"' "$WORK/release-$1.json" | sed 's/.*:[[:space:]]*"\([^"]*\)".*/\1/'
}

# the version of the site AT that tag. It must be the same as the tag.
version_at_tag() { json_version "$(fetch "$RAW/$GH_USER_NAME/$GH_REPO_NAME/$1/version.json")"; }

lower() { echo "$1" | tr 'A-Z' 'a-z'; }

# ---------------------------------------------------------------- the levels

level1() {
    title "Level 1 - publish the site"
    local code
    code="$(http_code "$SITE/")"
    if [ "$code" = "200" ]; then
        pass "your site answers: $SITE/"
    else
        fail "your site does not answer (HTTP $code): $SITE/"
        hint "Settings -> Pages -> Source: Deploy from a branch -> main / (root) -> Save. Then wait 1-2 minutes"
        hint "the repository must be PUBLIC, and the address is case sensitive: $GH_USER_NAME / $GH_REPO_NAME"
        return
    fi

    if fetch "$SITE/" | grep -qi '<html'; then
        pass "the page is an HTML page"
    else
        fail "the address answers, but it is not your HTML page (is index.html in the ROOT of the repository?)"
    fi

    local version
    version="$(live_version)"
    if is_semver "$version"; then
        pass "version.json says: $version"
        [ -f "$STATE" ] || echo "$version" >"$STATE"
    else
        fail "$SITE/version.json is missing or has no version like 1.0.0"
        hint "copy version.json from the site/ folder of the module, to the ROOT of your repository"
    fi
}

level2() {
    title "Level 2 - change the site and publish it again"
    local first current
    first="$(cat "$STATE" 2>/dev/null)"
    current="$(live_version)"
    if [ -z "$first" ]; then
        fail "no first version was saved. Pass level 1 first, then change the site"
        return
    fi
    if ! is_semver "$current"; then
        fail "the live site has no version in version.json"
        return
    fi
    if newer "$current" "$first"; then
        pass "the live version grew: $first -> $current"
    else
        fail "the live version is still $current. Change version.json (for example to 1.1.0), commit, push, and wait a minute"
        return
    fi
    if fetch "$SITE/changelog.json" | grep -Fq "\"$current\""; then
        pass "changelog.json has a line for version $current"
    else
        fail "changelog.json has no line for version $current. Add an entry: every release says what changed"
    fi
}

level3() {
    title "Level 3 - deploy with a GitHub Actions pipeline"
    local file="$GH_FOLDER/.github/workflows/pages.yml"
    if [ ! -f "$file" ] || [ -z "$(code_of "$file" | tr -d ' \n')" ]; then
        fail "the file .github/workflows/pages.yml is missing or has only comments"
        return
    fi
    local lacks
    for need in "actions/checkout@" "actions/configure-pages@" "actions/upload-pages-artifact@" "actions/deploy-pages@"; do
        if code_of "$file" | grep -Fq "$need"; then
            :
        else
            fail "pages.yml does not use $need (the 4 official steps: checkout, configure-pages, upload-pages-artifact, deploy-pages)"
            lacks=1
        fi
    done
    [ -z "${lacks:-}" ] && pass "pages.yml uses the 4 official actions"

    lacks="$(missing_in "$file" "pages: write" "id-token: write")"
    if [ -z "$lacks" ]; then
        pass "pages.yml has the permissions pages: write and id-token: write"
    else
        fail "pages.yml needs the permission '$lacks'"
    fi

    if code_of "$file" | grep -Eq 'branches:[[:space:]]*\[[[:space:]]*"?main"?[[:space:]]*\]|-[[:space:]]*"?main"?[[:space:]]*$'; then
        pass "the pipeline starts on a push to main"
    else
        fail "pages.yml must start on a push to the branch main:  on: push: branches: [main]"
    fi

    if code_of "$file" | grep -Eq 'name:[[:space:]]*github-pages|environment:[[:space:]]*github-pages'; then
        pass "the job uses the environment github-pages"
    else
        fail "the job needs the environment github-pages:  environment: name: github-pages"
    fi

    local runs
    runs="$(fetch "$API/repos/$GH_USER_NAME/$GH_REPO_NAME/actions/workflows/pages.yml/runs?status=success&per_page=1" \
        | tr -d '\n' | sed -n 's/.*"total_count"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')"
    if [ "${runs:-0}" -gt 0 ] 2>/dev/null; then
        pass "the pipeline ran successfully on GitHub ($runs time(s))"
    else
        fail "no successful run of pages.yml was found on GitHub"
        hint "Settings -> Pages -> Source must be 'GitHub Actions'. Push the file, open the Actions tab and look at the run"
    fi

    if [ "$(http_code "$SITE/")" = "200" ]; then
        pass "the site still answers"
    else
        fail "the site does not answer any more: $SITE/"
    fi
}

level4() {
    title "Level 4 - a version tag and a release (by hand)"
    local tags tag
    tags="$(release_tags)"
    if [ -z "$tags" ]; then
        fail "your repository has no published release"
        hint "git tag -a v1.1.0 -m \"Version 1.1.0\"  &&  git push origin v1.1.0   then GitHub -> Releases -> Draft a new release -> Publish"
        return
    fi

    # Look at every release that YOU made by hand, and keep the one that is nearest to being right.
    local best="" best_score=-1 score published notes agrees at_tag body_line
    for tag in $tags; do
        release_json "$tag" || continue
        [ "$(lower "$(release_author "$tag")")" = "$(lower "$GH_USER_NAME")" ] || continue
        score=0
        published=0; notes=0; agrees=0
        grep -q '"draft"[[:space:]]*:[[:space:]]*false' "$WORK/release-$tag.json" && { published=1; score=$((score + 1)); }
        body_line="$(grep -m1 '"body"' "$WORK/release-$tag.json" | sed 's/^[[:space:]]*"body"[[:space:]]*:[[:space:]]*//')"
        [ "${#body_line}" -gt 30 ] && { notes=1; score=$((score + 1)); }
        at_tag="$(version_at_tag "$tag")"
        [ "$at_tag" = "${tag#v}" ] && { agrees=1; score=$((score + 1)); }
        if [ "$score" -gt "$best_score" ]; then
            best="$tag"; best_score="$score"
            best_published="$published"; best_notes="$notes"; best_agrees="$agrees"; best_at_tag="$at_tag"
        fi
    done

    if [ -z "$best" ]; then
        fail "there are releases, but none was made by you by hand (the author must be $GH_USER_NAME)"
        return
    fi
    pass "release $best, published by you"
    [ "$best_published" = 1 ] && pass "it is published (not a draft)" \
        || fail "the release $best is a draft. Click 'Publish release'"
    [ "$best_notes" = 1 ] && pass "the release has release notes" \
        || fail "the release $best has no release notes. Write what changed (the button 'Generate release notes' helps)"
    [ "$best_agrees" = 1 ] && pass "the tag $best points to code that says version ${best#v} (the tag and the code agree)" \
        || fail "the tag $best points to code with version '${best_at_tag:-none}'. Bump version.json BEFORE you make the tag"
}

level5() {
    title "Level 5 - automatic releases"
    local file="$GH_FOLDER/.github/workflows/release.yml"
    if [ ! -f "$file" ] || [ -z "$(code_of "$file" | tr -d ' \n')" ]; then
        fail "the file .github/workflows/release.yml is missing or has only comments"
        return
    fi
    if code_of "$file" | grep -Eq "tags:" && code_of "$file" | grep -Eq "[\"']?v\*[\"']?"; then
        pass "release.yml starts when a tag v* is pushed"
    else
        fail "release.yml must start on a tag:  on: push: tags: ['v*']"
    fi
    if code_of "$file" | grep -Fq "contents: write"; then
        pass "release.yml has the permission contents: write"
    else
        fail "release.yml needs  permissions: contents: write  (a release writes to the repository)"
    fi
    if code_of "$file" | grep -Eq 'gh release create|action-gh-release'; then
        pass "release.yml creates the release"
    else
        fail "release.yml must create the release:  gh release create ..."
    fi
    if code_of "$file" | grep -Fq "site.zip"; then
        pass "release.yml attaches site.zip"
    else
        fail "release.yml must pack and attach site.zip"
    fi

    local tag found=""
    for tag in $(release_tags); do
        release_json "$tag" || continue
        if [ "$(release_author "$tag")" = "github-actions[bot]" ] && grep -q '"name"[[:space:]]*:[[:space:]]*"site.zip"' "$WORK/release-$tag.json"; then
            found="$tag"
            break
        fi
    done
    if [ -n "$found" ]; then
        pass "release $found was made by the pipeline, with the file site.zip"
        local at_tag
        at_tag="$(version_at_tag "$found")"
        if [ "$at_tag" = "${found#v}" ]; then
            pass "its tag and its code agree (version $at_tag)"
        else
            fail "the tag $found points to code with version '${at_tag:-none}'"
        fi
    else
        fail "no release was made by the pipeline yet"
        hint "bump version.json, commit, push, then:  git tag -a v1.2.0 -m \"Version 1.2.0\"  &&  git push origin v1.2.0   and open the Actions tab"
    fi
}

level6() {
    title "Level 6 - something went wrong: roll back"
    if [ "$(git -C "$GH_FOLDER" log --oneline -i --grep='^revert' 2>/dev/null | wc -l | tr -d ' ')" -gt 0 ]; then
        pass "your history has a revert commit (you undid a bad change with git revert)"
    else
        fail "no revert commit in your history"
        hint "git revert <the-bad-commit>  makes a NEW commit that undoes it, and keeps the history"
    fi

    local tags latest previous
    tags="$(release_tags)"
    latest="$(echo "$tags" | sed -n 1p)"
    previous="$(echo "$tags" | sed -n 2p)"
    if [ -z "$latest" ] || [ -z "$previous" ]; then
        fail "you need at least two releases (the bad one, and the fix)"
        return
    fi
    if newer "${latest#v}" "${previous#v}"; then
        pass "the newest release ($latest) is newer than the one before it ($previous)"
    else
        fail "the newest release $latest is not newer than $previous. A fix is a NEW, higher version (for example v1.3.1)"
    fi

    local live
    live="$(live_version)"
    if [ "$live" = "${latest#v}" ]; then
        pass "the live site shows the newest release: $live"
    else
        fail "the live site shows version '${live:-none}', but the newest release is ${latest#v}. Push the fix to main and wait a minute"
    fi
}

level7() {
    title "Level 7 (BONUS) - your own domain"
    if [ -z "${CUSTOM_DOMAIN:-}" ]; then
        skip "no custom domain given. To check it: CUSTOM_DOMAIN=www.example.com ./check.sh ..."
        return
    fi
    if grep -Fqx "$CUSTOM_DOMAIN" "$GH_FOLDER/CNAME" 2>/dev/null; then
        pass "the file CNAME in your repository says $CUSTOM_DOMAIN"
    else
        fail "the file CNAME must contain exactly one line: $CUSTOM_DOMAIN"
    fi
    if [ "$(http_code "https://$CUSTOM_DOMAIN/")" = "200" ]; then
        pass "https://$CUSTOM_DOMAIN/ answers"
    else
        fail "https://$CUSTOM_DOMAIN/ does not answer. Check the DNS records, then Settings -> Pages -> Custom domain. DNS can take hours"
    fi
}

# ---------------------------------------------------------------- main

echo "Site:       $SITE/"
echo "Repository: $GH_USER_NAME/$GH_REPO_NAME   (folder: $GH_FOLDER)"

RESULTS=""
for n in 1 2 3 4 5 6 7; do
    "level$n"
    if [ "$n" -eq 7 ] && [ "$SKIPPED" -gt 0 ] && [ -z "${CUSTOM_DOMAIN:-}" ]; then
        RESULTS="$RESULTS
  Level $n: skipped (bonus)"
    elif [ "$LEVEL_FAILED" -eq 0 ]; then
        RESULTS="$RESULTS
  Level $n: PASSED"
    else
        RESULTS="$RESULTS
  Level $n: not yet"
    fi
done

echo
echo "================ RESULT ================$RESULTS"
echo "  checks: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
