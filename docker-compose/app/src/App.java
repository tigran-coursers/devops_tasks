import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

/**
 * A web server that COUNTS VISITS in a PostgreSQL database. You do not change this file.
 *
 *   GET /health  -> "OK"
 *   GET /visits  -> "visits=<n>"   (every call adds 1 to the number in the database)
 *
 * It needs three environment variables:  DB_URL, DB_USER, DB_PASSWORD
 * Example DB_URL:  jdbc:postgresql://db:5432/visits      ("db" = the host name of the database)
 *
 * When it starts, it tries to connect to the database up to 60 times (one try per second).
 * It writes one line for every try, so you can see in "docker compose logs web" what happened:
 *     DB not ready (attempt 3): ...
 *     DB connected (attempt 1)
 */
public class App {

    private static Connection connection;

    public static void main(String[] args) throws Exception {
        String url = System.getenv("DB_URL");
        String user = System.getenv("DB_USER");
        String password = System.getenv("DB_PASSWORD");
        if (url == null || user == null || password == null) {
            System.err.println("Missing environment variable. DB_URL, DB_USER and DB_PASSWORD are required.");
            System.exit(1);
        }

        connection = connectWithRetry(url, user, password);
        try (Statement statement = connection.createStatement()) {
            statement.execute("create table if not exists visits (id int primary key, total bigint not null)");
            statement.execute("insert into visits (id, total) values (1, 0) on conflict do nothing");
        }

        int port = Integer.parseInt(System.getenv().getOrDefault("PORT", "8080"));
        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);
        server.createContext("/health", exchange -> reply(exchange, 200, "OK"));
        server.createContext("/visits", exchange -> {
            try {
                reply(exchange, 200, "visits=" + nextVisit());
            } catch (SQLException e) {
                reply(exchange, 500, "database error: " + e.getMessage());
            }
        });
        server.start();
        System.out.println("Listening on port " + port);
    }

    private static Connection connectWithRetry(String url, String user, String password) throws InterruptedException {
        for (int attempt = 1; attempt <= 60; attempt++) {
            try {
                Connection connected = DriverManager.getConnection(url, user, password);
                System.out.println("DB connected (attempt " + attempt + ")");
                return connected;
            } catch (SQLException e) {
                System.out.println("DB not ready (attempt " + attempt + "): " + e.getMessage());
                Thread.sleep(1000);
            }
        }
        System.err.println("Could not connect to the database. Giving up.");
        System.exit(1);
        return null;
    }

    private static synchronized long nextVisit() throws SQLException {
        try (Statement statement = connection.createStatement();
             ResultSet result = statement.executeQuery("update visits set total = total + 1 where id = 1 returning total")) {
            result.next();
            return result.getLong(1);
        }
    }

    private static void reply(HttpExchange exchange, int status, String text) throws IOException {
        byte[] body = text.getBytes(StandardCharsets.UTF_8);
        exchange.sendResponseHeaders(status, body.length);
        try (OutputStream out = exchange.getResponseBody()) {
            out.write(body);
        }
    }
}
