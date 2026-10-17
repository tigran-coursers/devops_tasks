import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;

/**
 * A tiny web server. It has NO libraries, only the Java that is already installed.
 * You do not change this file. You put it into a Docker image.
 *
 *   GET /        -> "Hello from Docker! greeting=<the value of the GREETING variable>"
 *   GET /health  -> "OK"
 *   GET /whoami  -> "user=<the user that runs the program>"
 *
 * The port comes from the PORT variable (default 8080).
 */
public class App {

    public static void main(String[] args) throws IOException {
        int port = Integer.parseInt(System.getenv().getOrDefault("PORT", "8080"));
        String greeting = System.getenv().getOrDefault("GREETING", "unset");

        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);
        server.createContext("/", exchange -> {
            if (exchange.getRequestURI().getPath().equals("/")) {
                reply(exchange, 200, "Hello from Docker! greeting=" + greeting);
            } else {
                reply(exchange, 404, "Not found");
            }
        });
        server.createContext("/health", exchange -> reply(exchange, 200, "OK"));
        server.createContext("/whoami", exchange -> reply(exchange, 200, "user=" + System.getProperty("user.name")));
        server.start();

        System.out.println("Listening on port " + port);
    }

    private static void reply(HttpExchange exchange, int status, String text) throws IOException {
        byte[] body = text.getBytes(StandardCharsets.UTF_8);
        exchange.sendResponseHeaders(status, body.length);
        try (OutputStream out = exchange.getResponseBody()) {
            out.write(body);
        }
    }
}
