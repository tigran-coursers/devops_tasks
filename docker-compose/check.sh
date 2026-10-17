#!/usr/bin/env bash
# Checks the compose files that you wrote.
#
#   ./check.sh        checks all 5 levels
#   ./check.sh 3      checks only level 3
#
# It starts your stack with docker compose, tests it, and stops it. It prints PASS or FAIL for every check.
# It only uses the project name "labcheck" and removes everything of that project at the end.
# Needs the ports 8090 (and 8091 in level 5) free on your computer.
# PROVIDED FILE - do not change.

set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
PROJECT="labcheck"
WEB="http://localhost:8090"
WORK="$(mktemp -d)"

PASSED=0
FAILED=0
LEVEL_FAILED=0
FILE=""

pass() { echo "  PASS  $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  FAIL  $1"; FAILED=$((FAILED + 1)); LEVEL_FAILED=1; }
hint() { echo "        -> $1"; }
title() { echo; echo "== $1"; LEVEL_FAILED=0; }

# ---------------------------------------------------------------- helpers

compose() { ( cd "$ROOT" && docker compose -f "$FILE" -p "$PROJECT" "$@" ); }

# removes everything that belongs to the project "labcheck", whatever file started it
force_cleanup() {
    docker ps -aq --filter "label=com.docker.compose.project=$PROJECT" | xargs docker rm -f >/dev/null 2>&1
    docker network ls -q --filter "label=com.docker.compose.project=$PROJECT" | xargs docker network rm >/dev/null 2>&1
    docker volume ls -q --filter "label=com.docker.compose.project=$PROJECT" | xargs docker volume rm >/dev/null 2>&1
    return 0
}
cleanup_all() { force_cleanup; rm -rf "$WORK"; }
trap cleanup_all EXIT

need_file() {
    FILE="compose.$1.yml"
    if [ ! -f "$ROOT/$FILE" ]; then
        fail "the file $FILE does not exist"
        return 1
    fi
    return 0
}

# config_ok: the compose file is valid
config_ok() {
    if compose config -q >"$WORK/config.log" 2>&1; then
        pass "$FILE is a valid compose file"
        return 0
    fi
    fail "$FILE is not a valid compose file"
    hint "docker compose says:"
    head -n 4 "$WORK/config.log" | sed 's/^/           /'
    return 1
}

# stack_up [extra args before "up"]: starts the stack. Returns 0 when it started.
stack_up() {
    if compose "$@" up -d --build >"$WORK/up.log" 2>&1; then
        return 0
    fi
    fail "docker compose up failed"
    hint "the last lines of the output:"
    tail -n 6 "$WORK/up.log" | sed 's/^/           /'
    if grep -qi "port is already allocated\|address already in use" "$WORK/up.log"; then
        hint "another program uses the port. Stop it (for example a Spring application on 8090/8091) and try again"
    fi
    return 1
}

wait_web() {
    local i=0
    while [ "$i" -lt "${1:-90}" ]; do
        [ "$(curl -fs --max-time 2 "$WEB/health" 2>/dev/null)" = "OK" ] && return 0
        sleep 1
        i=$((i + 1))
    done
    return 1
}

# visit: calls /visits and prints the number
visit() { curl -fs --max-time 5 "$WEB/visits" 2>/dev/null | sed 's/^visits=//'; }

container_of() {
    docker ps -aq --filter "label=com.docker.compose.project=$PROJECT" --filter "label=com.docker.compose.service=$1" | head -n 1
}

# the stack works: /health answers, and /visits counts 1 more every time
check_stack_works() {
    if ! wait_web 60; then
        fail "the web service does not answer on $WEB/health"
        hint "the logs of web:"
        compose logs --no-color --tail 6 web 2>&1 | sed 's/^/           /'
        if compose logs --no-color web 2>&1 | grep -q "localhost"; then
            hint "INSIDE a container, 'localhost' is the container itself. Use the NAME of the service: db"
        fi
        return 1
    fi
    pass "the web service answers on port 8090"
    local first second
    first="$(visit)"
    second="$(visit)"
    case "$first$second" in
        *[!0-9]*|"")
            fail "GET /visits does not answer a number (got '$first' and '$second')"
            hint "the web service cannot use the database. The logs of web:"
            compose logs --no-color --tail 6 web 2>&1 | sed 's/^/           /'
            return 1 ;;
    esac
    if [ "$second" -eq $((first + 1)) ]; then
        pass "the visits are counted in the database ($first, then $second)"
        return 0
    fi
    fail "the counter should grow by 1 (got $first, then $second)"
    return 1
}

# ---------------------------------------------------------------- levels

level1() {
    title "Level 1 - web and db (compose.1.yml)"
    need_file 1 || return
    config_ok || return
    force_cleanup
    stack_up || return
    pass "docker compose up works (the web image was built from ./app)"
    check_stack_works
    compose down -v >/dev/null 2>&1
}

level2() {
    title "Level 2 - a volume (compose.2.yml)"
    need_file 2 || return
    config_ok || return
    force_cleanup
    stack_up || return
    wait_web 60 || { fail "the web service does not start"; return; }
    visit >/dev/null; visit >/dev/null
    local before after
    before="$(visit)"
    if [ -z "$(docker volume ls -q --filter "label=com.docker.compose.project=$PROJECT")" ]; then
        fail "no volume was created. Declare the volume under 'volumes:' and use it in the db service"
    else
        pass "a named volume exists"
    fi

    compose down >/dev/null 2>&1          # NO -v: the volume stays
    stack_up || return
    wait_web 60 || { fail "the web service does not start the second time"; return; }
    after="$(visit)"
    if [ -n "$before" ] && [ "$after" = "$((before + 1))" ]; then
        pass "after 'down' and 'up', the counter continues ($before, then $after). The data survived"
    else
        fail "after 'down' and 'up', the counter is $after. It should be $((${before:-0} + 1))"
        hint "the db service needs   volumes: - dbdata:/var/lib/postgresql/data"
    fi
    compose down -v >/dev/null 2>&1
}

level3() {
    title "Level 3 - settings in .env (compose.3.yml)"
    need_file 3 || return
    config_ok || return
    # the text of the file without the comment lines
    local raw="$WORK/no-comments.yml"
    grep -v '^[[:space:]]*#' "$ROOT/$FILE" | sed 's/[[:space:]]#.*$//' > "$raw"
    if grep -q "secret123" "$raw"; then
        fail "the password is written in the compose file"
        hint "use  \${DB_PASSWORD}  (the value is in .env)"
    else
        pass "the password is not written in the compose file"
    fi
    if grep -q '\${' "$raw"; then
        pass "the file uses variables from .env"
    else
        fail "the file does not use any \${VARIABLE}"
    fi
    force_cleanup
    stack_up || return
    check_stack_works
    compose down -v >/dev/null 2>&1
}

level4() {
    title "Level 4 - healthcheck, depends_on, restart (compose.4.yml)"
    need_file 4 || return
    config_ok || return
    compose config >"$WORK/rendered.yml" 2>&1
    grep -q "healthcheck:" "$WORK/rendered.yml" && pass "the db has a healthcheck" || fail "there is no healthcheck. Add one to the db service"
    grep -q "service_healthy" "$WORK/rendered.yml" && pass "web waits for the db to be healthy (service_healthy)" \
        || { fail "web does not wait until the db is healthy"; hint "depends_on:  db:  condition: service_healthy"; }
    if grep -E "^\s+restart:" "$WORK/rendered.yml" | grep -qvE 'restart: ("?no"?)$'; then
        pass "a restart policy is set"
    else
        fail "no restart policy. Add  restart: unless-stopped  to web"
    fi

    force_cleanup
    stack_up || return
    check_stack_works || return
    local status
    status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$(container_of db)" 2>/dev/null)"
    [ "$status" = "healthy" ] && pass "Docker reports the db as healthy" || fail "the db is not healthy (status: $status)"
    if compose logs --no-color web 2>&1 | grep -q "DB connected (attempt 1)"; then
        pass "web connected to the db at the FIRST try (it waited for the db)"
    else
        fail "web did not connect at the first try. It started before the db was ready"
        hint "compose logs web  shows 'DB not ready'. Check depends_on with condition: service_healthy, and the healthcheck test"
        compose logs --no-color web 2>&1 | grep "DB " | head -n 3 | sed 's/^/           /'
    fi
    compose down -v >/dev/null 2>&1
}

networks_of() {
    docker inspect -f '{{range $name, $net := .NetworkSettings.Networks}}{{$name}} {{end}}' "$1" 2>/dev/null
}

level5() {
    title "Level 5 - networks and profiles (compose.5.yml)"
    need_file 5 || return
    config_ok || return
    force_cleanup
    stack_up || return
    check_stack_works || return

    local web db db_nets web_nets
    web="$(container_of web)"
    db="$(container_of db)"
    db_nets="$(networks_of "$db")"
    web_nets="$(networks_of "$web")"

    if [ "$(echo $db_nets | wc -w | tr -d ' ')" -eq 1 ] && echo "$db_nets" | grep -q backend; then
        pass "db is only on the backend network"
    else
        fail "db must be ONLY on the network 'backend' (it is on: $db_nets)"
    fi
    if echo "$web_nets" | grep -q backend && echo "$web_nets" | grep -q frontend; then
        pass "web is on both networks (frontend and backend)"
    else
        fail "web must be on both networks, frontend and backend (it is on: $web_nets)"
    fi
    if [ -z "$(docker port "$db" 2>/dev/null)" ]; then
        pass "db does not publish any port (nobody outside can reach it)"
    else
        fail "db publishes a port to your computer. Remove 'ports:' from the db service"
    fi
    if [ -z "$(container_of adminer)" ]; then
        pass "adminer was NOT started by a normal 'up' (it is in the profile 'tools')"
    else
        fail "adminer started without the profile. Add  profiles: [\"tools\"]"
    fi

    compose --profile tools up -d >"$WORK/up2.log" 2>&1
    local i=0 code=""
    while [ "$i" -lt 40 ]; do
        code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 http://localhost:8091 2>/dev/null)"
        [ "$code" = "200" ] && break
        sleep 1
        i=$((i + 1))
    done
    if [ "$code" = "200" ]; then
        pass "with --profile tools, adminer starts and answers on http://localhost:8091"
    else
        fail "with --profile tools, adminer does not answer on port 8091 (http code: $code)"
        hint "adminer: image: adminer, profiles: [\"tools\"], ports: [\"8091:8080\"], networks: [backend]"
    fi
    compose --profile tools down -v >/dev/null 2>&1
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
    for n in 1 2 3 4 5; do run_level "$n"; done
else
    case "$SELECTED" in
        1|2|3|4|5) run_level "$SELECTED" ;;
        *) echo "Usage: ./check.sh [1-5]"; exit 2 ;;
    esac
fi

echo
echo "================ RESULT ================$RESULTS"
echo "  checks: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
