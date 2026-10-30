package com.example.cicd.pipeline;

import org.junit.platform.engine.TestExecutionResult;
import org.junit.platform.engine.discovery.DiscoverySelectors;
import org.junit.platform.launcher.Launcher;
import org.junit.platform.launcher.LauncherDiscoveryRequest;
import org.junit.platform.launcher.TestExecutionListener;
import org.junit.platform.launcher.TestIdentifier;
import org.junit.platform.launcher.TestPlan;
import org.junit.platform.launcher.core.LauncherDiscoveryRequestBuilder;
import org.junit.platform.launcher.core.LauncherFactory;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/**
 * Runs PipelineTest and prints PASS or FAIL for every check, in the same style as the other modules.
 * Started by ./check.sh
 *
 * PROVIDED CODE - you do not change it.
 */
public class Check {

    public static void main(String[] args) {
        LauncherDiscoveryRequest request = LauncherDiscoveryRequestBuilder.request()
                .selectors(DiscoverySelectors.selectClass(PipelineTest.class))
                .build();

        Launcher launcher = LauncherFactory.create();
        PrintingListener listener = new PrintingListener();
        launcher.execute(request, listener);
        listener.printSorted();

        System.out.println();
        System.out.println("================ RESULT ================");
        System.out.println("  checks: " + listener.passed + " passed, " + listener.failed + " failed"
                + (listener.skipped > 0 ? ", " + listener.skipped + " bonus checks skipped (no deploy job)" : ""));
        System.exit(listener.failed == 0 ? 0 : 1);
    }

    private static class PrintingListener implements TestExecutionListener {
        record Line(String level, String name, String status, String message) {
        }

        int passed;
        int failed;
        int skipped;
        private final List<Line> lines = new ArrayList<>();
        private TestPlan plan;

        @Override
        public void testPlanExecutionStarted(TestPlan testPlan) {
            this.plan = testPlan;
        }

        @Override
        public void executionFinished(TestIdentifier test, TestExecutionResult result) {
            if (!test.isTest()) {
                return;
            }
            String level = plan.getParent(test).map(TestIdentifier::getDisplayName).orElse("");
            String message = result.getThrowable().map(Throwable::getMessage).orElse("");
            switch (result.getStatus()) {
                case SUCCESSFUL -> {
                    passed++;
                    lines.add(new Line(level, test.getDisplayName(), "PASS", ""));
                }
                case ABORTED -> {
                    skipped++;
                    lines.add(new Line(level, test.getDisplayName(), "SKIP", message));
                }
                default -> {
                    failed++;
                    lines.add(new Line(level, test.getDisplayName(), "FAIL", message));
                }
            }
        }

        /** JUnit runs the levels in any order. We print them in the order of the levels. */
        void printSorted() {
            lines.sort(Comparator.comparing(Line::level).thenComparing(Line::name));
            String lastLevel = "";
            String lastMessage = "";
            for (Line line : lines) {
                if (!line.level().equals(lastLevel)) {
                    System.out.println();
                    System.out.println("== " + line.level());
                    lastLevel = line.level();
                }
                System.out.println("  " + line.status() + "  " + line.name());
                if (!line.message().isEmpty()) {
                    // when a lot of checks fail for the same reason (an empty file, a YAML error), say it only once
                    System.out.println("        -> " + (line.message().equals(lastMessage) ? "(the same problem as above)" : line.message()));
                    lastMessage = line.message();
                }
            }
        }
    }
}
