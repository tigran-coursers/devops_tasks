# The image of the web application. It is FINISHED. In this module you do not write a Dockerfile:
# you write the compose files that run it together with a database.
# (You wrote Dockerfiles in the module "dockerfile".)
FROM eclipse-temurin:21-jdk AS build
WORKDIR /build
COPY src/App.java .
RUN javac -d classes App.java && jar --create --file app.jar --main-class App -C classes .

FROM eclipse-temurin:21-jre
WORKDIR /app
# the PostgreSQL driver, downloaded from Maven Central
ADD https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.4/postgresql-42.7.4.jar /app/lib/postgresql.jar
COPY --from=build /build/app.jar .
RUN useradd --create-home app && chmod 644 /app/lib/postgresql.jar
USER app
EXPOSE 8080
CMD ["java", "-cp", "app.jar:lib/postgresql.jar", "App"]
