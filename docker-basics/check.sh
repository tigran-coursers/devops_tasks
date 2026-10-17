#!/usr/bin/env bash
# Checks your answers in tasks.sh.
#
#   ./check.sh        runs all 10 tasks, in order
#   ./check.sh 5      runs only task 5
#
# It runs YOUR commands, and then looks at what exists in Docker (containers, ports, volumes ...).
# It only touches things named lab-... and removes them at the start and at the end.
# PROVIDED FILE - do not change.

set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
PASSED=0
FAILED=0
FAILED_TASKS=""

pass() { echo "  PASS  $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  FAIL  $1"; FAILED=$((FAILED + 1)); TASK_OK=0; }
hint() { echo "        -> $1"; }

remove_lab() {
    docker rm -f lab-web lab-web2 lab-site lab-limited >/dev/null 2>&1
    docker volume rm -f lab-notes >/dev/null 2>&1
    docker network rm lab-net >/dev/null 2>&1
}
cleanup() { remove_lab; rm -rf "$WORK"; }
trap cleanup EXIT

# run_task <n> [seconds]: runs the function task<n> of tasks.sh, in this folder, with a time limit
# (default 120 seconds, because the first "docker run" may have to download an image).
# The output is saved in $WORK/out-<n>.txt. Returns 1 when the time limit was reached.
run_task() {
    local n="$1" limit="${2:-120}" out="$WORK/out-$1.txt" pid i=0
    ( cd "$ROOT" && source ./tasks.sh && "task$n" ) >"$out" 2>&1 &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        if [ "$i" -ge "$limit" ]; then
            pkill -P "$pid" 2>/dev/null
            kill "$pid" 2>/dev/null
            echo "(the checker stopped your command after $limit seconds)" >>"$out"
            return 1
        fi
        sleep 1
        i=$((i + 1))
    done
    wait "$pid" 2>/dev/null
    return 0
}

output() { cat "$WORK/out-$1.txt"; }

# field <container> <go template>
field() { docker inspect -f "$2" "$1" 2>/dev/null; }

exists() { docker inspect "$1" >/dev/null 2>&1; }

# wait_page <url> <text>: waits (up to 15 s) until the page contains the text
wait_page() {
    local i=0
    while [ "$i" -lt 15 ]; do
        curl -fs --max-time 2 "$1" 2>/dev/null | grep -q "$2" && return 0
        sleep 1
        i=$((i + 1))
    done
    return 1
}

show_output() {
    hint "your command printed:"
    output "$1" | tail -n 5 | sed 's/^/           /'
}

# when a task is checked alone, the helper creates what the earlier tasks would have created
ensure_web() {
    exists lab-web || docker run -d --name lab-web -p 8081:80 nginx:alpine >/dev/null 2>&1
    wait_page http://localhost:8081 "Welcome to nginx"
}

# ------------------------------------------------------------------ the checks

check1() {
    if ! exists lab-web; then
        fail "there is no container named lab-web"
        hint "docker run -d --name lab-web -p 8081:80 nginx:alpine"
        show_output 1
        return
    fi
    if [ "$(field lab-web '{{.State.Running}}')" = "true" ]; then
        pass "the container lab-web is running"
    else
        fail "lab-web exists, but it is not running (did you forget -d, or did it stop?)"
    fi
    case "$(field lab-web '{{.Config.Image}}')" in
        nginx*) pass "it uses the image nginx:alpine" ;;
        *) fail "it should use the image nginx:alpine (it uses $(field lab-web '{{.Config.Image}}'))" ;;
    esac
    if wait_page http://localhost:8081 "Welcome to nginx"; then
        pass "http://localhost:8081 shows the nginx page"
    else
        fail "http://localhost:8081 does not answer"
        hint "the port must be 8081 on your computer and 80 in the container:  -p 8081:80"
    fi
}

check2() {
    exists lab-web || { fail "this task needs the container lab-web (task 1)"; return; }
    curl -fs --max-time 3 http://localhost:8081 >/dev/null 2>&1
    sleep 1
    if ! run_task 2 20; then
        fail "your command never ends. It must print the logs and stop"
        hint "docker logs -f keeps FOLLOWING the logs forever. Remove the -f"
        return
    fi
    if output 2 | grep -q "GET / HTTP"; then
        pass "your command printed the logs of lab-web"
    else
        fail "the output has no line 'GET / HTTP'. It should be the logs of lab-web"
        hint "docker logs lab-web"
        show_output 2
    fi
}

check3() {
    exists lab-web || { fail "this task needs the container lab-web (task 1)"; return; }
    run_task 3 30
    if [ "$(docker exec lab-web cat /tmp/note.txt 2>/dev/null)" = "hello" ]; then
        pass "the file /tmp/note.txt in lab-web contains: hello"
    else
        fail "the file /tmp/note.txt inside lab-web does not contain exactly 'hello'"
        hint "docker exec lab-web sh -c 'echo hello > /tmp/note.txt'"
    fi
    if output 3 | grep -q "hello"; then
        pass "your command printed the file"
    else
        fail "your command did not print the content of the file"
        hint "a second docker exec:  docker exec lab-web cat /tmp/note.txt"
    fi
}

check4() {
    local before after
    before="$(docker ps -aq | wc -l | tr -d ' ')"
    run_task 4
    after="$(docker ps -aq | wc -l | tr -d ' ')"
    if output 4 | grep -q "Salut"; then
        pass "the container printed: Salut"
        if [ "$before" = "$after" ]; then
            pass "no container was left behind (--rm)"
        else
            fail "a stopped container was left behind. Use --rm"
        fi
    else
        fail "the output should contain 'Salut'"
        hint "single quotes: docker run --rm -e GREETING=Salut alpine sh -c 'echo \$GREETING'"
        show_output 4
    fi
}

check5() {
    run_task 5
    if docker volume inspect lab-notes >/dev/null 2>&1; then
        pass "the volume lab-notes exists"
    else
        fail "there is no volume named lab-notes"
        hint "docker run --rm -v lab-notes:/data alpine sh -c 'echo saved > /data/note.txt'"
        return
    fi
    if output 5 | grep -q "saved"; then
        pass "a second container read the file from the volume: saved"
    else
        fail "the output should contain 'saved' (read from the volume by a second container)"
        show_output 5
    fi
}

check6() {
    run_task 6
    if ! exists lab-site; then
        fail "there is no container named lab-site"
        show_output 6
        return
    fi
    if wait_page http://localhost:8082 "My Docker site"; then
        pass "http://localhost:8082 shows your page"
    else
        fail "http://localhost:8082 does not show 'My Docker site'"
        hint "-v \"\$(pwd)/site:/usr/share/nginx/html:ro\"   and   -p 8082:80"
    fi
    case "$(field lab-site '{{range .Mounts}}{{.Type}}:{{.RW}} {{end}}')" in
        *"bind:false"*) pass "the folder is mounted read-only (:ro)" ;;
        *) fail "the folder is not a read-only bind mount. Add :ro at the end of the -v value" ;;
    esac
}

check7() {
    run_task 7
    if docker network inspect lab-net >/dev/null 2>&1; then
        pass "the network lab-net exists"
    else
        fail "there is no network named lab-net"
        hint "docker network create lab-net"
        return
    fi
    if ! exists lab-web2; then
        fail "there is no container named lab-web2"
        return
    fi
    if [ "$(field lab-web2 '{{json .NetworkSettings.Networks}}' | grep -c 'lab-net')" -ge 1 ]; then
        pass "lab-web2 is on the network lab-net"
    else
        fail "lab-web2 is not on the network lab-net (--network lab-net)"
    fi
    case "$(field lab-web2 '{{json .HostConfig.PortBindings}}')" in
        "{}"|"null") pass "lab-web2 has no published port (only containers on the network can reach it)" ;;
        *) fail "lab-web2 must not publish a port. Remove -p" ;;
    esac
    if output 7 | grep -q "Welcome to nginx"; then
        pass "another container downloaded the page with the NAME lab-web2 as the address"
    else
        fail "the output has no 'Welcome to nginx'"
        hint "docker run --rm --network lab-net alpine wget -qO- http://lab-web2"
        show_output 7
    fi
}

check8() {
    exists lab-web || { fail "this task needs the container lab-web (task 1)"; return; }
    run_task 8 30
    if [ "$(output 8 | tr -d ' \r\n')" = "nginx:alpine" ]; then
        pass "your command printed exactly: nginx:alpine"
    else
        fail "the output must be exactly 'nginx:alpine' (nothing else)"
        hint "docker inspect -f '{{.Config.Image}}' lab-web"
        show_output 8
    fi
}

check9() {
    run_task 9
    if ! exists lab-limited; then
        fail "there is no container named lab-limited"
        show_output 9
        return
    fi
    if [ "$(field lab-limited '{{.State.Running}}')" = "true" ]; then
        pass "lab-limited is running"
    else
        fail "lab-limited is not running (command: sleep 300, and -d)"
    fi
    if [ "$(field lab-limited '{{.HostConfig.Memory}}')" = "67108864" ]; then
        pass "the memory limit is 64 MB"
    else
        fail "the memory limit should be 64m (it is $(field lab-limited '{{.HostConfig.Memory}}') bytes)"
        hint "--memory 64m"
    fi
    if [ "$(field lab-limited '{{.HostConfig.NanoCpus}}')" = "500000000" ]; then
        pass "the CPU limit is 0.5"
    else
        fail "the CPU limit should be 0.5 (--cpus 0.5)"
    fi
}

# the checker creates everything that the tasks 1-9 create (if it is not there yet),
# so that "clean up" has something to clean
create_lab_state() {
    docker network create lab-net >/dev/null 2>&1
    docker volume create lab-notes >/dev/null 2>&1
    exists lab-web || docker run -d --name lab-web nginx:alpine >/dev/null 2>&1
    exists lab-web2 || docker run -d --name lab-web2 --network lab-net nginx:alpine >/dev/null 2>&1
    exists lab-site || docker run -d --name lab-site nginx:alpine >/dev/null 2>&1
    exists lab-limited || docker run -d --name lab-limited alpine sleep 300 >/dev/null 2>&1
}

check10() {
    create_lab_state
    run_task 10
    local left=""
    for name in lab-web lab-web2 lab-site lab-limited; do
        exists "$name" && left="$left $name"
    done
    if [ -z "$left" ]; then
        pass "all the containers are removed"
    else
        fail "these containers still exist:$left"
        hint "docker rm -f <name>  (-f also removes a running container)"
    fi
    docker volume inspect lab-notes >/dev/null 2>&1 && fail "the volume lab-notes still exists" || pass "the volume is removed"
    docker network inspect lab-net >/dev/null 2>&1 && fail "the network lab-net still exists (remove the containers first)" || pass "the network is removed"
}

# ------------------------------------------------------------------ main

if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running. Start Docker Desktop and try again."
    exit 2
fi

TITLES=("" "run a container" "logs" "exec" "a container that removes itself" "a volume" \
        "a bind mount" "a network" "inspect" "limits" "clean up")

run_check() {
    local n="$1"
    TASK_OK=1
    echo
    echo "== Task $n - ${TITLES[$n]}"
    if [ "$n" -ne 1 ] && [ "$ONLY" != "all" ]; then
        case "$n" in 2|3|8) ensure_web ;; esac
    fi
    # Task 1 is run here. The other checks run their task themselves, at the right moment
    # (for example task 2 needs somebody to open the page first, so that the log has a line).
    [ "$n" -eq 1 ] && run_task 1
    "check$n"
    if [ "$TASK_OK" -eq 1 ]; then
        RESULTS="$RESULTS
  Task $n: PASSED"
    else
        RESULTS="$RESULTS
  Task $n: not yet"
    fi
}

echo "Cleaning old lab-... containers first."
remove_lab
ONLY="${1:-all}"
RESULTS=""

if [ "$ONLY" = "all" ]; then
    for n in 1 2 3 4 5 6 7 8 9 10; do run_check "$n"; done
else
    case "$ONLY" in
        1|2|3|4|5|6|7|8|9|10) run_check "$ONLY" ;;
        *) echo "Usage: ./check.sh [1-10]"; exit 2 ;;
    esac
fi

echo
echo "================ RESULT ================$RESULTS"
echo "  checks: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
