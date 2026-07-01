FROM        --platform=$TARGETOS/$TARGETARCH rust:1.56-slim

LABEL       author="Ethan Coward" maintainer="ethan.coward@icloud.com"

RUN         apt update \
                && apt -y install git dnsutils curl iproute2 ffmpeg tini pkg-config \
                && useradd -m -d /home/container container

RUN 		apt-get install -y locales \
			&& sed -i -e 's/# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen \
			&& sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
			&& locale-gen
ENV         LANG=en_US.UTF-8 \
            LANGUAGE=en_US:zh_CN \
            LC_ALL=en_US.UTF-8
USER        container
ENV         USER=container HOME=/home/container CARGO_HOME=/home/container/.cargo
WORKDIR     /home/container

STOPSIGNAL SIGINT

COPY        --chown=container:container ./../entrypoint.sh /entrypoint.sh
RUN         chmod +x /entrypoint.sh
ENTRYPOINT    ["/usr/bin/tini", "-g", "--"]
CMD         ["/entrypoint.sh"]