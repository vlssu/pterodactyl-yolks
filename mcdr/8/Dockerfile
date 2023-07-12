FROM        --platform=$TARGETOS/$TARGETARCH python:3.11-slim

LABEL       author="vlssu" maintainer="vlssu@vlssu.com"

RUN         apt update \
            && apt -y install git gcc g++ ca-certificates dnsutils curl iproute2 ffmpeg procps \
            && useradd -m -d /home/container container

ENV         JAVA_HOME=/opt/java/openjdk
COPY        --from=eclipse-temurin:8-jdk-focal $JAVA_HOME $JAVA_HOME
ENV         PATH="${JAVA_HOME}/bin:${PATH}"

RUN         pip install mcdreforged parse hjson pycryptodome colorlog py-cpuinfo simpleeval

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

COPY        ./../entrypoint.sh /entrypoint.sh
CMD         [ "/bin/bash", "/entrypoint.sh" ]
