FROM        --platform=$TARGETOS/$TARGETARCH python:3.11-slim

LABEL       author="vlssu" maintainer="vlssu@pterodactyl.top"

ARG         ZULU_REPO_VER=1.0.0-3

RUN         apt update \
            && apt -y install git gcc g++ ca-certificates dnsutils curl iproute2 ffmpeg procps \
            && useradd -m -d /home/container container

RUN         apt-get -qq update && \
            apt-get -qq -y --no-install-recommends install gnupg software-properties-common locales curl tzdata && \
            echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
            locale-gen en_US.UTF-8 && \
            apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0xB1998361219BD9C9 && \
            curl -sLO https://cdn.azul.com/zulu/bin/zulu-repo_${ZULU_REPO_VER}_all.deb && dpkg -i zulu-repo_${ZULU_REPO_VER}_all.deb && \
            apt-get -qq update && \
            apt-get -qq -y dist-upgrade && \
            mkdir -p /usr/share/man/man1 && \
            echo "Package: zulu8-*\nPin: version 8.0.352-*\nPin-Priority: 1001" > /etc/apt/preferences && \
            apt-get -qq -y --no-install-recommends install zulu8-jdk=8.0.352-* && \
            apt-get -qq -y purge gnupg software-properties-common curl && \
            apt -y autoremove && \
            rm -rf /var/lib/apt/lists/* zulu-repo_${ZULU_REPO_VER}_all.deb

RUN         pip install mcdreforged parse hjson

ENV         JAVA_HOME=/usr/lib/jvm/zulu8-ca-amd64

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

COPY        ./../entrypoint.sh /entrypoint.sh
CMD         [ "/bin/bash", "/entrypoint.sh" ]
