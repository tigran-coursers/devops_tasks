# Used only by the OPTIONAL deploy level: a hosting service (for example Render) builds this file on ITS servers.
# You do not need Docker on your computer for this module.
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN mvn -B package -DskipTests

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /build/target/cicd-demo.jar app.jar
RUN useradd --create-home app
USER app
EXPOSE 8080
CMD ["java", "-jar", "app.jar"]
