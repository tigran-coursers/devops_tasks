package com.example.cicd.pipeline;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.MethodOrderer;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestMethodOrder;
import org.yaml.snakeyaml.Yaml;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assumptions.assumeTrue;

/**
 * READS your pipeline file (.github/workflows/ci.yml) and checks it, level by level.
 * It does not run the pipeline (only GitHub can do that). It checks that the file says the right things.
 * Run it with ./check.sh
 *
 * PROVIDED CODE - you do not change it.
 */
@Tag("pipeline")
class PipelineTest {

    private static final Path FILE = Path.of(".github", "workflows", "ci.yml");

    // ------------------------------------------------------------------ helpers (they make clean messages: only the hint)

    private static void assertTrue(boolean condition, String hint) {
        if (!condition) {
            throw new AssertionError(hint);
        }
    }

    private static void assertFalse(boolean condition, String hint) {
        assertTrue(!condition, hint);
    }

    private static void assertNotNull(Object value, String hint) {
        assertTrue(value != null, hint);
    }

    private static void assertEquals(String expected, String actual, String hint) {
        assertTrue(expected.equals(actual), hint);
    }

    // ------------------------------------------------------------------ helpers (reading the YAML)

    private static String text() {
        try {
            return Files.readString(FILE);
        } catch (IOException e) {
            return "";
        }
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> workflow() {
        assertTrue(Files.exists(FILE), "The file .github/workflows/ci.yml does not exist");
        Object loaded;
        try {
            loaded = new Yaml().load(text());
        } catch (RuntimeException e) {
            String firstLine = String.valueOf(e.getMessage()).split("\n")[0];
            throw new AssertionError("The file is not valid YAML (" + firstLine + "). Check the spaces: YAML uses spaces, never tabs");
        }
        assertNotNull(loaded, "The file is empty (only comments). Write the pipeline: start with 'name:' and 'on:'");
        assertTrue(loaded instanceof Map, "The file must be a YAML map (lines like 'name: ...' and 'jobs: ...')");
        return (Map<String, Object>) loaded;
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> asMap(Object value) {
        return value instanceof Map ? (Map<String, Object>) value : Map.of();
    }

    private static List<Object> asList(Object value) {
        if (value instanceof List<?> list) {
            return new ArrayList<>(list);
        }
        return value == null ? new ArrayList<>() : new ArrayList<>(List.of(value));
    }

    /** The "on:" key. (In YAML 1.1 the word "on" is read as the boolean true, so we look for both.) */
    private static Object trigger() {
        Map<String, Object> workflow = workflow();
        Object value = workflow.get("on");
        if (value == null) {
            for (Map.Entry<String, Object> entry : workflow.entrySet()) {
                if (String.valueOf(entry.getKey()).equals("true")) {
                    value = entry.getValue();
                }
            }
        }
        return value;
    }

    private static Map<String, Object> jobs() {
        return asMap(workflow().get("jobs"));
    }

    private static Map<String, Object> job(String id) {
        assertTrue(jobs().containsKey(id), "There is no job named '" + id + "' under 'jobs:'");
        return asMap(jobs().get(id));
    }

    private static List<Map<String, Object>> steps(String jobId) {
        List<Map<String, Object>> steps = new ArrayList<>();
        for (Object step : asList(job(jobId).get("steps"))) {
            steps.add(asMap(step));
        }
        return steps;
    }

    /** The first step of the job that uses this action, or null. */
    private static Map<String, Object> stepUsing(String jobId, String action) {
        for (Map<String, Object> step : steps(jobId)) {
            if (String.valueOf(step.getOrDefault("uses", "")).startsWith(action)) {
                return step;
            }
        }
        return null;
    }

    /** All the shell commands of the job, joined in one text. */
    private static String commands(String jobId) {
        StringBuilder all = new StringBuilder();
        for (Map<String, Object> step : steps(jobId)) {
            if (step.get("run") != null) {
                all.append(step.get("run")).append("\n");
            }
        }
        return all.toString();
    }

    private static List<String> needs(String jobId) {
        List<String> result = new ArrayList<>();
        for (Object item : asList(job(jobId).get("needs"))) {
            result.add(String.valueOf(item));
        }
        return result;
    }

    // ------------------------------------------------------------------ the levels

    @Nested
    @DisplayName("Level 1 - the file and the trigger")
    @TestMethodOrder(MethodOrderer.DisplayName.class)
    class Level1 {

        @Test
        @DisplayName("1.1 the file .github/workflows/ci.yml exists and is not only comments")
        void fileExists() {
            assertTrue(Files.exists(FILE), "Create the file .github/workflows/ci.yml (GitHub looks for pipelines exactly there)");
            boolean hasContent = text().lines().anyMatch(line -> !line.isBlank() && !line.trim().startsWith("#"));
            assertTrue(hasContent, "The file has only comments. Write the pipeline (start with 'name:' and 'on:')");
        }

        @Test
        @DisplayName("1.2 the file is valid YAML and has a name")
        void hasAName() {
            Object name = workflow().get("name");
            assertTrue(name instanceof String && !((String) name).isBlank(), "Add a line at the top:  name: CI/CD");
        }

        @Test
        @DisplayName("1.3 the pipeline starts on a push to the branch main")
        void startsOnPushToMain() {
            Map<String, Object> push = asMap(asMap(trigger()).get("push"));
            assertTrue(asList(push.get("branches")).contains("main"),
                    "Write:  on:  push:  branches: [main]   (a push to the branch main starts the pipeline)");
        }

        @Test
        @DisplayName("1.4 the pipeline does NOT start on pushes to every branch")
        void notOnEveryBranch() {
            Map<String, Object> push = asMap(asMap(trigger()).get("push"));
            List<Object> branches = asList(push.get("branches"));
            assertFalse(branches.contains("**") || branches.contains("*"), "Only the branch main must start the pipeline");
            assertFalse(branches.isEmpty(), "Under 'push:' add  branches: [main]. Without it, every branch starts the pipeline");
        }
    }

    @Nested
    @DisplayName("Level 2 - the three stages (jobs)")
    @TestMethodOrder(MethodOrderer.DisplayName.class)
    class Level2 {

        @Test
        @DisplayName("2.1 there are three jobs: build, test and package")
        void threeJobs() {
            for (String id : List.of("build", "test", "package")) {
                assertTrue(jobs().containsKey(id), "Add a job named '" + id + "' under 'jobs:'");
            }
        }

        @Test
        @DisplayName("2.2 every job runs on a Linux machine (ubuntu-latest)")
        void runsOnUbuntu() {
            for (String id : List.of("build", "test", "package")) {
                assertTrue(String.valueOf(job(id).get("runs-on")).startsWith("ubuntu-"), "Job '" + id + "': add  runs-on: ubuntu-latest");
            }
        }

        @Test
        @DisplayName("2.3 every job downloads the code of the repository (actions/checkout)")
        void checksOut() {
            for (String id : List.of("build", "test", "package")) {
                assertNotNull(stepUsing(id, "actions/checkout@"),
                        "Job '" + id + "': a new job starts on an EMPTY machine. First step:  - uses: actions/checkout@v4");
            }
        }

        @Test
        @DisplayName("2.4 every job installs Java 21 (actions/setup-java)")
        void installsJava() {
            for (String id : List.of("build", "test", "package")) {
                Map<String, Object> step = stepUsing(id, "actions/setup-java@");
                assertNotNull(step, "Job '" + id + "': add a step  - uses: actions/setup-java@v4  with  distribution: temurin  and  java-version: '21'");
                assertEquals("21", String.valueOf(asMap(step.get("with")).get("java-version")), "Job '" + id + "': java-version must be '21'");
            }
        }
    }

    @Nested
    @DisplayName("Level 3 - the commands and the order")
    @TestMethodOrder(MethodOrderer.DisplayName.class)
    class Level3 {

        @Test
        @DisplayName("3.1 build compiles the code:  mvn compile")
        void buildCompiles() {
            String run = commands("build");
            assertTrue(run.contains("mvn") && run.contains("compile"), "Job 'build': add a step  run: mvn -B compile");
        }

        @Test
        @DisplayName("3.2 test runs the tests:  mvn test")
        void testRunsTests() {
            String run = commands("test");
            assertTrue(run.contains("mvn") && (run.contains(" test") || run.contains("verify")), "Job 'test': add a step  run: mvn -B test");
            assertFalse(run.contains("-DskipTests") || run.contains("-Dmaven.test.skip"), "Job 'test' must RUN the tests, not skip them");
        }

        @Test
        @DisplayName("3.3 package builds the jar and does not run the tests again")
        void packageBuildsTheJar() {
            String run = commands("package");
            assertTrue(run.contains("mvn") && run.contains("package"), "Job 'package': add a step  run: mvn -B package -DskipTests");
            assertTrue(run.contains("-DskipTests") || run.contains("-Dmaven.test.skip"),
                    "The tests already ran in the stage 'test'. Add  -DskipTests  to the package command");
        }

        @Test
        @DisplayName("3.4 test starts only after build succeeded (needs: build)")
        void testNeedsBuild() {
            assertTrue(needs("test").contains("build"), "Job 'test': add  needs: build   (without it, the jobs run at the same time)");
        }

        @Test
        @DisplayName("3.5 package starts only after test succeeded (needs: test)")
        void packageNeedsTest() {
            assertTrue(needs("package").contains("test"), "Job 'package': add  needs: test   (a broken build must never be packaged)");
        }

        @Test
        @DisplayName("3.6 build does not need anything: it is the first stage")
        void buildIsFirst() {
            assertTrue(needs("build").isEmpty(), "Job 'build' is the first stage: it must not have 'needs:'");
        }
    }

    @Nested
    @DisplayName("Level 4 - the artifacts (the results that you keep)")
    @TestMethodOrder(MethodOrderer.DisplayName.class)
    class Level4 {

        @Test
        @DisplayName("4.1 package keeps the jar (actions/upload-artifact)")
        void packageKeepsTheJar() {
            Map<String, Object> step = stepUsing("package", "actions/upload-artifact@");
            assertNotNull(step, "Job 'package': add a step  - uses: actions/upload-artifact@v4  with  name: ...  and  path: target/cicd-demo.jar");
            String path = String.valueOf(asMap(step.get("with")).get("path"));
            assertTrue(path.contains("target/") && path.contains(".jar"), "The path of the artifact must be the jar:  path: target/cicd-demo.jar");
        }

        @Test
        @DisplayName("4.2 test keeps the test reports (target/surefire-reports)")
        void testKeepsTheReports() {
            Map<String, Object> step = stepUsing("test", "actions/upload-artifact@");
            assertNotNull(step, "Job 'test': add a step that uploads the folder target/surefire-reports with actions/upload-artifact@v4");
            assertTrue(String.valueOf(asMap(step.get("with")).get("path")).contains("surefire-reports"),
                    "The path of the test artifact must be target/surefire-reports");
        }

        @Test
        @DisplayName("4.3 the test reports are kept even when the tests FAIL (if: always())")
        void reportsEvenWhenTestsFail() {
            Map<String, Object> step = stepUsing("test", "actions/upload-artifact@");
            assertNotNull(step, "Job 'test': upload the test reports first (see 4.2)");
            assertTrue(String.valueOf(step.get("if")).contains("always()"),
                    "When the tests fail, the next steps are skipped, and you lose the reports that explain the failure. Add  if: always()  to the upload step");
        }
    }

    @Nested
    @DisplayName("Level 5 - speed and safety")
    @TestMethodOrder(MethodOrderer.DisplayName.class)
    class Level5 {

        @Test
        @DisplayName("5.1 the Maven downloads are cached (cache: maven)")
        void mavenCache() {
            for (String id : List.of("build", "test", "package")) {
                Map<String, Object> setupJava = stepUsing(id, "actions/setup-java@");
                boolean cached = setupJava != null && "maven".equals(String.valueOf(asMap(setupJava.get("with")).get("cache")))
                        || stepUsing(id, "actions/cache@") != null;
                assertTrue(cached, "Job '" + id + "': under 'with:' of setup-java add  cache: maven  (the libraries are not downloaded again every time)");
            }
        }

        @Test
        @DisplayName("5.2 the pipeline can only READ the repository (permissions: contents: read)")
        void leastPermissions() {
            Map<String, Object> permissions = asMap(workflow().get("permissions"));
            assertEquals("read", String.valueOf(permissions.get("contents")),
                    "At the top level add:  permissions:  contents: read   (give a pipeline only the power it needs)");
        }

        @Test
        @DisplayName("5.3 every job has a time limit (timeout-minutes)")
        void timeouts() {
            for (String id : jobs().keySet()) {
                assertNotNull(job(id).get("timeout-minutes"), "Job '" + id + "': add  timeout-minutes: 10   (a stuck job must not run for hours)");
            }
        }

        @Test
        @DisplayName("5.4 a new push cancels the old run of the same branch (concurrency)")
        void concurrency() {
            Map<String, Object> concurrency = asMap(workflow().get("concurrency"));
            assertEquals("true", String.valueOf(concurrency.get("cancel-in-progress")),
                    "Add at the top level:  concurrency:  group: ${{ github.workflow }}-${{ github.ref }}  cancel-in-progress: true");
            assertNotNull(concurrency.get("group"), "concurrency needs a 'group:'");
        }

        @Test
        @DisplayName("5.5 there is no secret written in the file")
        void noSecrets() {
            workflow();   // there must be a real pipeline file first
            String text = text();
            assertFalse(text.contains("api.render.com/deploy") || text.contains("ghp_") || text.matches("(?s).*(password|token)\\s*:\\s*['\"]?[A-Za-z0-9]{12,}.*"),
                    "Never write a URL with a key, a token or a password in the file. Use  ${{ secrets.NAME }}");
        }
    }

    @Nested
    @DisplayName("Level 6 - deploy to a free server (BONUS)")
    @TestMethodOrder(MethodOrderer.DisplayName.class)
    class Level6 {

        private void needDeployJob() {
            assumeTrue(jobs().containsKey("deploy"), "BONUS: there is no job named 'deploy' yet");
        }

        @Test
        @DisplayName("6.1 deploy starts only after package succeeded (needs: package)")
        void deployNeedsPackage() {
            needDeployJob();
            assertTrue(needs("deploy").contains("package"), "Job 'deploy': add  needs: package");
        }

        @Test
        @DisplayName("6.2 deploy is a GitHub environment named production")
        void environment() {
            needDeployJob();
            Object environment = job("deploy").get("environment");
            String name = environment instanceof Map ? String.valueOf(asMap(environment).get("name")) : String.valueOf(environment);
            assertEquals("production", name, "Job 'deploy': add  environment: production   (GitHub shows the deployments of an environment)");
        }

        @Test
        @DisplayName("6.3 deploy calls the deploy hook, with the URL from a secret")
        void callsTheHook() {
            needDeployJob();
            String run = commands("deploy");
            assertTrue(run.contains("curl") && run.contains("secrets.RENDER_DEPLOY_HOOK_URL"),
                    "Job 'deploy': add a step  run: curl -fsS -X POST \"${{ secrets.RENDER_DEPLOY_HOOK_URL }}\"");
        }

        @Test
        @DisplayName("6.4 the deploy fails the pipeline when the server says no (curl -f)")
        void curlFails() {
            needDeployJob();
            java.util.regex.Matcher curl = java.util.regex.Pattern.compile("curl\\b([^\\n;&|]*)").matcher(commands("deploy"));
            int found = 0;
            while (curl.find()) {
                found++;
                String arguments = " " + curl.group(1);
                assertTrue(arguments.matches("(?s).*\\s-[a-zA-Z]*f[a-zA-Z]*(\\s.*)?") || arguments.contains("--fail"),
                        "EVERY curl needs -f (for example  curl -fsS ...). Without -f, curl succeeds even when the server answers an error, and the pipeline stays green. This one has none: curl" + curl.group(1).stripTrailing());
            }
            assertTrue(found > 0, "Job 'deploy': call the deploy hook with  curl -fsS -X POST ...");
        }

        @Test
        @DisplayName("6.5 after the deploy, a smoke test calls /health of the running application")
        void smokeTest() {
            needDeployJob();
            String run = commands("deploy");
            assertTrue(run.contains("/health") && (run.contains("APP_URL") || run.contains("vars.APP_URL")),
                    "Add a step that calls  $APP_URL/health  (put  APP_URL: ${{ vars.APP_URL }}  under 'env:' of the step) and retries until it answers");
        }
    }
}
