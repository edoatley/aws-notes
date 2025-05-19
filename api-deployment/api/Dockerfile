# Build stage
FROM eclipse-temurin:17-jdk-alpine as builder
WORKDIR /app
# Copy gradle files first to cache dependencies layer
COPY gradle/ gradle/
COPY build.gradle gradle.properties settings.gradle gradlew ./
# Download dependencies
RUN ./gradlew --no-daemon dependencies

# Copy source code and build the application
COPY src/ src/
RUN ./gradlew --no-daemon bootJar && \
    mkdir -p build/dependency && \
    cd build/dependency && \
    jar -xf ../libs/*.jar

# Run stage
FROM eclipse-temurin:17-jre-alpine
RUN apk add --no-cache curl
VOLUME /tmp
ARG DEPENDENCY=/app/build/dependency
COPY --from=builder ${DEPENDENCY}/BOOT-INF/lib /app/lib
COPY --from=builder ${DEPENDENCY}/META-INF /app/META-INF
COPY --from=builder ${DEPENDENCY}/BOOT-INF/classes /app
EXPOSE 8080
ENTRYPOINT ["java", \
    "-XX:+UseContainerSupport", \
    "-XX:MaxRAMPercentage=75.0", \
    "-XX:InitialRAMPercentage=50.0", \
    "-cp", "/app:/app/lib/*", \
    "com.example.api.ProductApiApplication"]