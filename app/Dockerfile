# [인프라 1주차] 워크북 3.7 deploy.sh 의
#   docker buildx build --platform linux/arm64 --provenance=false -t "${ECR}:${SHA}" --push .
# 를 그대로 실행할 수 있도록 만든 Dockerfile (빌드 컨텍스트 = app/)

# ── 1단계: jar 빌드 ─────────────────────────────────────────────
# $BUILDPLATFORM = 빌드하는 내 PC(amd64). jar 는 CPU 와 무관하므로
# ARM 에뮬레이션 없이 내 PC 아키텍처로 빠르게 빌드한다.
FROM --platform=$BUILDPLATFORM eclipse-temurin:21-jdk AS build
WORKDIR /src
COPY gradlew settings.gradle build.gradle ./
COPY gradle ./gradle
RUN chmod +x gradlew
COPY src ./src
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew bootJar -x test --no-daemon \
 && cp build/libs/*-SNAPSHOT.jar /app.jar

# ── 2단계: 실행 이미지 ──────────────────────────────────────────
# --platform linux/arm64 로 빌드하면 ARM(Graviton, t4g) 용 JRE 가 선택된다.
# 이 단계에는 RUN 이 없어서 에뮬레이션이 필요 없다.
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app.jar /app/app.jar
EXPOSE 3000
# exec 형식(JSON 배열) → java 가 PID 1 이 되어 docker stop 의 SIGTERM 을 직접 받는다 (워크북 4.1 "PID 1")
# t4g.micro 메모리 1GB → JVM 이 컨테이너 메모리의 50% 까지만 힙으로 쓰게 제한
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=50", "-jar", "/app/app.jar"]
