FROM gradle:8.9-jdk21-alpine AS build
WORKDIR /app
COPY . .
RUN ./gradlew :muffin-wallet-server:bootJar -x test

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
ENV SPRING_PROFILES_ACTIVE=prod
COPY --from=build /app/muffin-wallet-server/build/libs/*-1.0.0.jar /app/app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
