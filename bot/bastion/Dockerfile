FROM        --platform=$TARGETOS/$TARGETARCH mongo:6-focal

LABEL       author="Michael Parker" maintainer="parker@pterodactyl.io"

## install nodejs 18
RUN apt update && apt install --no-install-recommends -y curl \ 
 && mkdir -p /etc/apt/keyrings \
 && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_18.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
 && apt update && apt install -y nodejs \
 && npm install -g npm@latest \
 ## install bastion reqs
 && apt install -y python3 build-essential git libtool netcat ffmpeg iproute2 tzdata tini \
 ## add container user
 && useradd -d /home/container -m container -s /bin/bash

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

STOPSIGNAL SIGINT

COPY        --chown=container:container ./entrypoint.sh /entrypoint.sh
RUN         chmod +x /entrypoint.sh
ENTRYPOINT    ["/usr/bin/tini", "-g", "--"]
CMD         ["/entrypoint.sh"]