# STAGE 1: BUILD
FROM maven:3.9.6-eclipse-temurin-21 AS builder
WORKDIR /app

COPY pom.xml .
RUN mvn dependency:go-offline -B

COPY src ./src
RUN mvn clean package -DskipTests

# STAGE 2: RUN
FROM eclipse-temurin:21-jre-jammy
WORKDIR /app
# pg_dump/pg_restore for the admin backups: jammy ships client 14, which refuses the PostgreSQL 15 server, so the
# client comes from the PostgreSQL apt repository at the server's major version.
RUN apt-get update && apt-get install -y curl tini ca-certificates \
    && install -d /usr/share/postgresql-common/pgdg \
    && curl -fsSL -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    && echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt jammy-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update && apt-get install -y --no-install-recommends postgresql-client-15 \
    && rm -rf /var/lib/apt/lists/*
# mongodump/mongorestore for the MongoDB backups of the admin page: only the database tools, from the MongoDB 7.0 apt
# repository (jammy has no package of them); apt reads the armored key as it is. They also read the archives of a 6.0 server.
RUN install -d /usr/share/keyrings \
    && curl -fsSL -o /usr/share/keyrings/mongodb-server-7.0.asc https://pgp.mongodb.com/server-7.0.asc \
    && echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.asc] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" > /etc/apt/sources.list.d/mongodb-org-7.0.list \
    && apt-get update && apt-get install -y --no-install-recommends mongodb-database-tools \
    && rm -rf /var/lib/apt/lists/*
ENV TZ="Asia/Ho_Chi_Minh"
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
ENV SPRING_PROFILES_ACTIVE="prod"
RUN addgroup --system spring && adduser --system --ingroup spring spring
# BackupService writes into <working dir>/backups; the volume mounted there must belong to the app user.
RUN mkdir -p /app/backups && chown spring:spring /app/backups
COPY --from=builder --chown=spring:spring /app/target/finance-api.jar app.jar
USER spring:spring

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["tini", "--", "java", "-XX:MaxRAMPercentage=75.0", "-XX:InitialRAMPercentage=50.0", "-Dspring.profiles.active=${SPRING_PROFILES_ACTIVE}", "-jar", "app.jar"]