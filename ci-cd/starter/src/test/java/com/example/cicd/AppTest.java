package com.example.cicd;

import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Starts the real server on a free port and calls it over HTTP.
 * These tests run in the TEST stage of your pipeline. PROVIDED CODE - you do not change them.
 */
class AppTest {

    private static HttpServer server;
    private static String baseUrl;
    private static final HttpClient CLIENT = HttpClient.newHttpClient();

    @BeforeAll
    static void startServer() throws Exception {
        server = App.createServer(0);
        server.start();
        baseUrl = "http://localhost:" + server.getAddress().getPort();
    }

    @AfterAll
    static void stopServer() {
        server.stop(0);
    }

    private static HttpResponse<String> get(String path) throws Exception {
        return CLIENT.send(HttpRequest.newBuilder(URI.create(baseUrl + path)).build(), HttpResponse.BodyHandlers.ofString());
    }

    @Test
    void health_isOk() throws Exception {
        HttpResponse<String> response = get("/health");

        assertEquals(200, response.statusCode());
        assertEquals("OK", response.body());
    }

    @Test
    void greet_withAName() throws Exception {
        assertEquals("Hello, Anna!", get("/greet?name=Anna").body());
    }

    @Test
    void greet_decodesTheName() throws Exception {
        assertEquals("Hello, Anna Smith!", get("/greet?name=Anna%20Smith").body());
    }

    @Test
    void greet_withoutName() throws Exception {
        assertEquals("Hello, world!", get("/greet").body());
    }

    @Test
    void version_showsTheVersionAndTheBuild() throws Exception {
        assertTrue(get("/version").body().startsWith("version 1.0.0 (build "), "the version text was: " + get("/version").body());
    }

    @Test
    void unknownPage_is404() throws Exception {
        assertEquals(404, get("/nothing-here").statusCode());
    }
}
