FROM   --platform=$TARGETOS/$TARGETARCH oven/bun:canary

LABEL author="MrAtox" maintainer="mratox@protonmail.com"

RUN  apt update \
            && apt -y install ffmpeg iproute2 git sqlite3 libsqlite3-dev python3 python3-dev ca-certificates dnsutils tzdata zip tar curl build-essential libtool tini \
            && useradd -m -d /home/container container

RUN bun upgrade

RUN 		apt-get install -y locales \
			&& sed -i -e 's/# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen \
			&& sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
			&& locale-gen
ENV         LANG=en_US.UTF-8 \
            LANGUAGE=en_US:zh_CN \
            LC_ALL=en_US.UTF-8
USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

STOPSIGNAL SIGINT

COPY        --chown=container:container ./../entrypoint.sh /entrypoint.sh
RUN         chmod +x /entrypoint.sh
ENTRYPOINT    ["/usr/bin/tini", "-g", "--"]
CMD         ["/entrypoint.sh"]