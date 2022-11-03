FROM        --platform=$TARGETOS/$TARGETARCH python:3.11-slim

LABEL       author="vlssu" maintainer="vlssu@pterodactyl.top"

ARG         ZULU_REPO_VER=1.0.0-2

RUN         apt update \
            && apt -y install git gcc g++ ca-certificates dnsutils curl iproute2 ffmpeg procps \
            && useradd -m -d /home/container container

RUN         apt-get -qq update && \
            apt-get -qq -y --no-install-recommends install gnupg software-properties-common locales curl && \
            locale-gen en_US.UTF-8 && \
            apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0x219BD9C9 && \
            curl -sLO https://cdn.azul.com/zulu/bin/zulu-repo_${ZULU_REPO_VER}_all.deb && dpkg -i zulu-repo_${ZULU_REPO_VER}_all.deb && \
            apt-get -qq update && \
            apt-get -qq -y dist-upgrade && \
            mkdir -p /usr/share/man/man1 && \
            echo "Package: zulu16-*\nPin: version 16.32+15*\nPin-Priority: 1001" > /etc/apt/preferences && \
            apt-get -qq -y --no-install-recommends install zulu16-jdk=16.0.2-* && \
            apt-get -qq -y purge gnupg software-properties-common curl && \
            apt -y autoremove && \
            rm -rf /var/lib/apt/lists/* zulu-repo_${ZULU_REPO_VER}_all.deb

RUN         pip install mcdreforged parse hjson

ENV         JAVA_HOME=/usr/lib/jvm/zulu16-ca-amd64

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

COPY        ./../entrypoint.sh /entrypoint.sh
CMD         [ "/bin/bash", "/entrypoint.sh" ]
