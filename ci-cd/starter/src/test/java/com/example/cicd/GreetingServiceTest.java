package com.example.cicd;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

/** These tests run in the TEST stage of your pipeline. PROVIDED CODE - you do not change them. */
class GreetingServiceTest {

    @Test
    void greet_usesTheName() {
        assertEquals("Hello, Anna!", GreetingService.greet("Anna"));
    }

    @Test
    void greet_removesSpacesAroundTheName() {
        assertEquals("Hello, Anna!", GreetingService.greet("  Anna  "));
    }

    @Test
    void greet_withoutName_greetsTheWorld() {
        assertEquals("Hello, world!", GreetingService.greet(null));
    }

    @Test
    void greet_withBlankName_greetsTheWorld() {
        assertEquals("Hello, world!", GreetingService.greet("   "));
    }
}
