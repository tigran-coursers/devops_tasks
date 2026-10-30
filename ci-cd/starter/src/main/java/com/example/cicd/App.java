package com.example.cicd;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;

/**
 * A tiny web application, with no libraries (only the Java that is already installed):
 *
 *   GET /            a short welcome text
 *   GET /health      "OK"   (a deployment checks this address to know that the application is alive)
 *   GET /greet?name=Anna     "Hello, Anna!"
 *   GET /version     "version 1.0.0 (build 42)"
 *
 * The port comes from the PORT environment variable (hosting services set it), and is 8080 by default.
 *
 * PROVIDED CODE - you do not change it.
 */
public class App {

    public static void main(String[] args) throws IOException {
        int port = Integer.parseInt(System.getenv().getOrDefault("PORT", "8080"));
        createServer(port).start();
        System.out.println("cicd-demo " + VersionInfo.text() + " is listening on port " + port);
    }

    /** Creates the server (it is not started yet). Port 0 means "any free port": the tests use it. */
    public static HttpServer createServer(int port) throws IOException {
        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);
        server.createContext("/health", exchange -> reply(exchange, 200, "OK"));
        server.createContext("/version", exchange -> reply(exchange, 200, VersionInfo.text()));
        server.createContext("/greet", exchange ->
                reply(exchange, 200, GreetingService.greet(queryParameter(exchange.getRequestURI().getRawQuery(), "name"))));
        server.createContext("/", exchange -> {
            if (exchange.getRequestURI().getPath().equals("/")) {
                reply(exchange, 200, "Hello from the CI/CD demo. Try /health, /greet?name=Anna and /version");
            } else {
                reply(exchange, 404, "Not found");
            }
        });
        return server;
    }

    private static String queryParameter(String query, String name) {
        if (query == null) {
            return null;
        }
        for (String pair : query.split("&")) {
            String[] parts = pair.split("=", 2);
            if (parts.length == 2 && parts[0].equals(name)) {
                return URLDecoder.decode(parts[1], StandardCharsets.UTF_8);
            }
        }
        return null;
    }

    private static void reply(HttpExchange exchange, int status, String text) throws IOException {
        byte[] body = text.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().add("Content-Type", "text/plain; charset=utf-8");
        exchange.sendResponseHeaders(status, body.length);
        try (OutputStream out = exchange.getResponseBody()) {
            out.write(body);
        }
    }
}
