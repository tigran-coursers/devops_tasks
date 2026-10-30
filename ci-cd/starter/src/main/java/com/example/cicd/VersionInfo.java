package com.example.cicd;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

/**
 * Tells which version, and which BUILD, of the application is running. The numbers are written into
 * version.properties by Maven when the application is packaged. A pipeline gives the build number
 * (mvn package -Dbuild.number=42), so you can see in the running application which build it is.
 *
 * PROVIDED CODE - you do not change it.
 */
public final class VersionInfo {

    private VersionInfo() {
    }

    /** For example: "version 1.0.0 (build 42)". */
    public static String text() {
        Properties properties = new Properties();
        try (InputStream in = VersionInfo.class.getResourceAsStream("/version.properties")) {
            if (in != null) {
                properties.load(in);
            }
        } catch (IOException e) {
            throw new IllegalStateException("Cannot read version.properties", e);
        }
        return "version " + properties.getProperty("app.version", "?") + " (build " + properties.getProperty("build.number", "?") + ")";
    }
}
