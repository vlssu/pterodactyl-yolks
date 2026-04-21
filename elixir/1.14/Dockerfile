FROM --platform=$TARGETOS/$TARGETARCH elixir:1.14.5-slim

LABEL author="MrAvox" maintainer="mravox@proton.me"

RUN  apt update \
            && apt -y install git dnsutils curl iproute2 ffmpeg tini \
            && useradd -m -d /home/container container

RUN 		apt-get install -y locales \
			&& locale-gen zh_CN.UTF-8

USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

STOPSIGNAL SIGINT

COPY        --chown=container:container ./../entrypoint.sh /entrypoint.sh
RUN         chmod +x /entrypoint.sh
ENTRYPOINT    ["/usr/bin/tini", "-g", "--"]
CMD         ["/entrypoint.sh"]
