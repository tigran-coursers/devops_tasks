#!/usr/bin/env bash
# Checks your pipeline.
#
#   ./check.sh
#
# Step 1: the three commands that your pipeline will run (compile, test, package) must work on your own computer.
#         If they fail here, they will fail in the pipeline too.
# Step 2: it reads your file .github/workflows/ci.yml and checks it, level by level.
#
# It does NOT run the pipeline: only GitHub can do that. Push your repository, open the "Actions" tab, and watch.
# PROVIDED FILE - do not change.

cd "$(dirname "$0")" || exit 2

if ! command -v mvn >/dev/null 2>&1; then
    echo "Maven (mvn) is not installed. Install Maven and JDK 21, then try again."
    exit 2
fi

FAILED=0
step() {
    local name="$1"
    shift
    if "$@" >/tmp/cicd-check.log 2>&1; then
        echo "  PASS  $name"
    else
        echo "  FAIL  $name"
        tail -n 8 /tmp/cicd-check.log | sed 's/^/           /'
        FAILED=1
    fi
}

echo "== Step 1 - the commands of the pipeline work on your computer"
step "mvn -B compile" mvn -q -B compile
step "mvn -B test" mvn -q -B test
step "mvn -B package -DskipTests" mvn -q -B package -DskipTests
rm -f /tmp/cicd-check.log

echo
echo "== Step 2 - your pipeline file (.github/workflows/ci.yml)"
mvn -q -B test-compile org.codehaus.mojo:exec-maven-plugin:3.5.0:java \
    -Dexec.mainClass=com.example.cicd.pipeline.Check -Dexec.classpathScope=test 2>&1 \
    | grep -vE "^WARNING|SLF4J"
RESULT=${PIPESTATUS[0]}

[ "$FAILED" -eq 0 ] && [ "$RESULT" -eq 0 ]
