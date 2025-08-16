# ---------- Build stage ----------
FROM maven:3.9.8-eclipse-temurin-21 AS build
WORKDIR /build

# 优化缓存：分步复制 pom.xml 和源码
COPY pom.xml .
RUN mvn -q -B -DskipTests dependency:go-offline

# 构建完成后清理可能残留 Maven 缓存
COPY src ./src
RUN mvn -q -B -DskipTests package && \
    rm -rf ~/.m2/repository

# ---------- Runtime stage ----------
# 使用 Alpine 版本 的 JRE 镜像以减少运行时镜像大小
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# 使用最小用户和权限
# 多个命令放在一个 RUN 以减少镜像层数
RUN apk add --no-cache shadow && \
    useradd -r -u 10001 app && \
    chown -R app /app && \
    apk del shadow
USER app

# 复制构建产物（明确 JAR 名称）
COPY --from=build /build/target/app.jar /app/app.jar

EXPOSE 8080
ENV JAVA_OPTS=""

# HEALTHCHECK 在 Kubernetes 中可能会被探针覆盖
# 可选：健康检查（容器层面；K8s里仍以 probe 为准）
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/actuator/health || exit 1

ENTRYPOINT ["sh","-lc","exec /opt/java/openjdk/bin/java $JAVA_OPTS -jar /app/app.jar"]
