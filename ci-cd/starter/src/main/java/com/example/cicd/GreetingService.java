package com.example.cicd;

/**
 * The "business logic" of the demo application. It is tiny on purpose:
 * the application is only here to give the pipeline something to build, test and package.
 *
 * PROVIDED CODE - you do not change it.
 */
public final class GreetingService {

    private GreetingService() {
    }

    /** "Hello, Anna!". A missing or blank name gives "Hello, world!". */
    public static String greet(String name) {
        if (name == null || name.isBlank()) {
            return "Hello, world!";
        }
        return "Hello, " + name.trim() + "!";
    }
}
