#!/usr/bin/env bash
# Checks the Dockerfiles that you wrote.
#
#   ./check.sh        checks all 6 levels
#   ./check.sh 3      checks only level 3
#
# It builds your image, starts a container, and tests it. It prints PASS or FAIL for every check,
# and tells you what to look at. It only touches things named "labcheck-..." and removes them at the end.
# PROVIDED FILE - do not change.

set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/app"
IMAGE="labcheck-hello"
CONTAINER="labcheck-app"
PORT=18080
WORK="$(mktemp -d)"

PASSED=0
FAILED=0
LEVEL_FAILED=0

# ---------------------------------------------------------------- small helpers

pass() { echo "  PASS  $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  FAIL  $1"; FAILED=$((FAILED + 1)); LEVEL_FAILED=1; }
hint() { echo "        -> $1"; }
title() { echo; echo "== $1"; LEVEL_FAILED=0; }

cleanup_container() { docker rm -f "$CONTAINER" >/dev/null 2>&1; }

cleanup_all() {
    cleanup_container
    docker images --format '{{.Repository}}:{{.Tag}}' | grep "^$IMAGE:" | xargs docker rmi -f >/dev/null 2>&1
    rm -rf "$WORK"
}
trap cleanup_all EXIT

# build <tag> <level> <context-dir> [extra docker build args...]
# Saves the output in $WORK/build-<tag>.log. Returns 0 when the build works.
build() {
    local tag="$1" level="$2" context="$3"
    shift 3
    docker build --progress=plain -f "$context/Dockerfile.$level" -t "$IMAGE:$tag" "$@" "$context" \
        >"$WORK/build-$tag.log" 2>&1
}

show_build_error() {
    if grep -q "file with no instructions" "$WORK/build-$1.log"; then
        hint "the Dockerfile has no instructions yet (only comments). Write the lines from the TODO"
        return
    fi
    hint "the build failed. The last lines of the output:"
    tail -n 8 "$WORK/build-$1.log" | sed 's/^/           /'
}

# start <tag> [extra docker run args...]
start_app() {
    local tag="$1"
    shift
    cleanup_container
    docker run -d --name "$CONTAINER" -p "$PORT:8080" "$@" "$IMAGE:$tag" >/dev/null 2>&1
}

get() { curl -fs --max-time 3 "http://localhost:$PORT$1" 2>/dev/null; }

# wait_for_app <seconds>: waits until GET /health answers
wait_for_app() {
    local i=0
    while [ "$i" -lt "$1" ]; do
        [ "$(get /health)" = "OK" ] && return 0
        sleep 1
        i=$((i + 1))
    done
    return 1
}

# the app works: GET / and GET /health
check_app_answers() {
    local tag="$1"
    if wait_for_app 30; then
        pass "the container starts and /health answers OK"
    else
        fail "the container does not answer on port 8080"
        hint "the container logs:"
        docker logs "$CONTAINER" 2>&1 | tail -n 5 | sed 's/^/           /'
        return 1
    fi
    return 0
}

image_field() { docker image inspect -f "$2" "$IMAGE:$1" 2>/dev/null; }

health_status() {
    docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$CONTAINER" 2>/dev/null
}

need_dockerfile() {
    if [ ! -f "$APP/Dockerfile.$1" ]; then
        fail "the file app/Dockerfile.$1 does not exist"
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------- the levels

level1() {
    title "Level 1 - the first image (Dockerfile.1)"
    need_dockerfile 1 || return
    if build 1 1 "$APP"; then
        pass "the image builds"
    else
        fail "the image does not build"
        show_build_error 1
        return
    fi

    start_app 1
    check_app_answers 1 || return

    local body
    body="$(get /)"
    case "$body" in
        *"Hello from Docker"*) pass "GET / answers: $body" ;;
        *) fail "GET / should answer 'Hello from Docker! ...', but it answered: $body" ;;
    esac

    if image_field 1 '{{json .Config.ExposedPorts}}' | grep -q '8080/tcp'; then
        pass "the image says it uses port 8080 (EXPOSE)"
    else
        fail "the image does not EXPOSE port 8080"
        hint "add the line:  EXPOSE 8080"
    fi

    local start
    start="$(image_field 1 '{{json .Config.Entrypoint}} {{json .Config.Cmd}}')"
    if echo "$start" | grep -q '"/bin/sh","-c"'; then
        fail "CMD is in the SHELL form. It starts a shell first"
        hint "use the exec form with brackets:  CMD [\"java\", \"App.java\"]"
    else
        pass "CMD is in the exec form (no shell in front of your program)"
    fi
    cleanup_container
}

level2() {
    title "Level 2 - ENV, ARG, LABEL (Dockerfile.2)"
    need_dockerfile 2 || return
    if build 2 2 "$APP"; then
        pass "the image builds"
    else
        fail "the image does not build"
        show_build_error 2
        return
    fi

    start_app 2
    check_app_answers 2 || return
    case "$(get /)" in
        *"greeting=Welcome"*) pass "the default GREETING is Welcome (ENV)" ;;
        *) fail "without -e, GET / should contain 'greeting=Welcome', but it answered: $(get /)"
           hint "add:  ENV GREETING=Welcome" ;;
    esac

    start_app 2 -e GREETING=Salut
    wait_for_app 30
    case "$(get /)" in
        *"greeting=Salut"*) pass "docker run -e GREETING=Salut changes the greeting" ;;
        *) fail "with -e GREETING=Salut the greeting did not change: $(get /)" ;;
    esac
    cleanup_container

    local title_label version
    title_label="$(image_field 2 '{{index .Config.Labels "org.opencontainers.image.title"}}')"
    if [ "$title_label" = "hello-app" ]; then
        pass "the label org.opencontainers.image.title is hello-app"
    else
        fail "the label org.opencontainers.image.title should be hello-app (it is '$title_label')"
    fi

    version="$(image_field 2 '{{index .Config.Labels "version"}}')"
    if [ "$version" = "1.0" ]; then
        pass "the default label version is 1.0 (from the ARG default)"
    else
        fail "the label version should be 1.0 by default (it is '$version')"
        hint "ARG APP_VERSION=1.0   then   LABEL version=\"\$APP_VERSION\""
    fi

    if build 2v 2 "$APP" --build-arg APP_VERSION=2.5; then
        version="$(image_field 2v '{{index .Config.Labels "version"}}')"
        if [ "$version" = "2.5" ]; then
            pass "docker build --build-arg APP_VERSION=2.5 gives the label version=2.5"
        else
            fail "with --build-arg APP_VERSION=2.5 the label version should be 2.5 (it is '$version')"
            hint "the ARG line must come BEFORE the LABEL line"
        fi
    fi
}

level3() {
    title "Level 3 - layers and the cache (Dockerfile.3)"
    need_dockerfile 3 || return
    if build 3a 3 "$APP"; then
        pass "the image builds"
    else
        fail "the image does not build"
        show_build_error 3a
        return
    fi

    start_app 3a
    check_app_answers 3a || return
    cleanup_container

    local id1 id2
    id1="$(docker run --rm --entrypoint cat "$IMAGE:3a" /app/deps-id 2>/dev/null)"
    if [ -z "$id1" ]; then
        fail "the file /app/deps-id does not exist in the image"
        hint "run  sh install-deps.sh  (or the right path) with the working directory /app"
        return
    fi
    pass "the slow script was run (it wrote /app/deps-id)"

    # a copy of the project where the source file is changed
    cp -R "$APP" "$WORK/changed"
    echo "// a small change" >> "$WORK/changed/src/App.java"
    if ! build 3b 3 "$WORK/changed"; then
        fail "the image does not build after a change of the source"
        show_build_error 3b
        return
    fi
    id2="$(docker run --rm --entrypoint cat "$IMAGE:3b" /app/deps-id 2>/dev/null)"
    if [ "$id1" = "$id2" ]; then
        pass "after a change of src/App.java, the slow script was NOT run again (the cache works)"
    else
        fail "after a change of src/App.java, the slow script ran AGAIN (every build is slow)"
        hint "copy and run scripts/install-deps.sh BEFORE you copy src/App.java"
    fi
}

# the biggest "transferring context" number in a build log, in bytes
max_context_bytes() {
    grep -o 'transferring context: [0-9.]*[kMG]*B' "$1" | sed 's/transferring context: //' |
        awk '{
            value = $0 + 0
            if ($0 ~ /GB$/) value = value * 1000000000
            else if ($0 ~ /MB$/) value = value * 1000000
            else if ($0 ~ /kB$/) value = value * 1000
            if (value > max) max = value
        } END { printf "%d", max }'
}

level4() {
    title "Level 4 - a small build context (.dockerignore)"
    need_dockerfile 4 || return
    if [ ! -f "$APP/.dockerignore" ]; then
        fail "the file app/.dockerignore does not exist"
        return
    fi

    cp -R "$APP" "$WORK/junky"
    mkdir -p "$WORK/junky/junk"
    head -c 20000000 /dev/zero > "$WORK/junky/junk/big.bin"
    head -c 1000000 /dev/zero > "$WORK/junky/debug.log"

    if ! docker build --progress=plain --no-cache -f "$WORK/junky/Dockerfile.4" -t "$IMAGE:4" "$WORK/junky" \
            >"$WORK/build-4.log" 2>&1; then
        fail "the image does not build"
        show_build_error 4
        return
    fi
    pass "the image builds"

    local bytes
    bytes="$(max_context_bytes "$WORK/build-4.log")"
    if [ "${bytes:-0}" -lt 5000000 ]; then
        pass "Docker sent only $((bytes / 1000)) kB of files to the engine (the junk is ignored)"
    else
        fail "Docker sent $((bytes / 1000000)) MB of files. The 20 MB junk file was sent too"
        hint "add  junk/  and  *.log  to app/.dockerignore"
    fi

    start_app 4
    check_app_answers 4 || return
    cleanup_container
}

check_not_root() {
    local tag="$1" body user
    body="$(get /whoami)"
    user="$(image_field "$tag" '{{.Config.User}}')"
    if [ "$body" = "user=root" ] || [ -z "$user" ] || [ "$user" = "root" ] || [ "$user" = "0" ]; then
        fail "the app runs as root (/whoami says: $body)"
        hint "RUN useradd --create-home app   and then   USER app"
    else
        pass "the app does not run as root (/whoami says: $body)"
    fi
}

check_healthy() {
    local i=0 status
    while [ "$i" -lt 60 ]; do
        status="$(health_status)"
        [ "$status" = "healthy" ] && { pass "Docker says the container is healthy (HEALTHCHECK)"; return; }
        sleep 1
        i=$((i + 1))
    done
    fail "the container did not become healthy in 60 seconds (status: $status)"
    if [ "$status" = "none" ]; then
        hint "add a HEALTHCHECK instruction"
    else
        hint "run the healthcheck command by hand: docker exec $CONTAINER curl -f http://localhost:8080/health"
    fi
}

level5() {
    title "Level 5 - not root, and a healthcheck (Dockerfile.5)"
    need_dockerfile 5 || return
    if build 5 5 "$APP"; then
        pass "the image builds"
    else
        fail "the image does not build"
        show_build_error 5
        return
    fi

    start_app 5
    check_app_answers 5 || return
    check_not_root 5
    check_healthy
    cleanup_container
}

level6() {
    title "Level 6 - multi-stage build (Dockerfile.6)"
    need_dockerfile 6 || return
    local from_lines
    from_lines="$(grep -ci '^FROM ' "$APP/Dockerfile.6")"
    if [ "$from_lines" -ge 2 ]; then
        pass "the Dockerfile has $from_lines stages (FROM lines)"
    else
        fail "the Dockerfile has $from_lines FROM line. A multi-stage build needs at least 2"
    fi

    if build 6 6 "$APP"; then
        pass "the image builds"
    else
        fail "the image does not build"
        show_build_error 6
        return
    fi

    start_app 6
    check_app_answers 6 || return
    check_not_root 6
    check_healthy
    cleanup_container

    if docker run --rm --entrypoint sh "$IMAGE:6" -c 'command -v javac' >/dev/null 2>&1; then
        fail "the final image still has the compiler (javac). It is the JDK image"
        hint "the LAST stage must start from eclipse-temurin:21-jre (not -jdk)"
    else
        pass "the final image has no compiler (javac)"
    fi

    # The size depends on how Docker counts it on your computer. So we compare with the plain JDK image,
    # measured in the same way. A final image on the JRE is about half of it. An image on the JDK is bigger.
    local size jdk limit
    docker image inspect eclipse-temurin:21-jdk >/dev/null 2>&1 || docker pull -q eclipse-temurin:21-jdk >/dev/null 2>&1
    size="$(image_field 6 '{{.Size}}')"
    jdk="$(docker image inspect -f '{{.Size}}' eclipse-temurin:21-jdk 2>/dev/null)"
    limit=$((${jdk:-0} * 80 / 100))
    if [ "${size:-999999999999}" -lt "$limit" ]; then
        pass "the image is small: $((size / 1000000)) MB (the JDK image is $((jdk / 1000000)) MB)"
    else
        fail "the image is $((size / 1000000)) MB, almost as big as the JDK image ($((jdk / 1000000)) MB)"
        hint "the final stage must use the JRE image and copy only app.jar from the build stage"
    fi
}

# ---------------------------------------------------------------- main

if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running. Start Docker Desktop and try again."
    exit 2
fi

SELECTED="${1:-all}"
RESULTS=""

run_level() {
    "level$1"
    if [ "$LEVEL_FAILED" -eq 0 ]; then
        RESULTS="$RESULTS
  Level $1: PASSED"
    else
        RESULTS="$RESULTS
  Level $1: not yet"
    fi
}

if [ "$SELECTED" = "all" ]; then
    for n in 1 2 3 4 5 6; do run_level "$n"; done
else
    case "$SELECTED" in
        1|2|3|4|5|6) run_level "$SELECTED" ;;
        *) echo "Usage: ./check.sh [1-6]"; exit 2 ;;
    esac
fi

echo
echo "================ RESULT ================$RESULTS"
echo "  checks: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
