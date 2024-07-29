FROM 		--platform=$TARGETOS/$TARGETARCH debian:bookworm-slim

ENV         DEBIAN_FRONTEND=noninteractive

RUN			dpkg --add-architecture i386 \
			&& apt update \
			&& apt upgrade -y \
			&& apt install -y lib32gcc-s1 lib32stdc++6 unzip curl iproute2 tzdata libgdiplus libsdl2-2.0-0:i386 \
			&& curl -sL https://deb.nodesource.com/setup_14.x | bash - \
			&& apt install -y nodejs \
			&& mkdir /node_modules \
			&& npm install --prefix / ws \
			&& useradd -d /home/container -m container

RUN 		apt-get install -y locales
RUN 		sed -i -e 's/# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen
ENV 		LANG en_US.UTF-8
ENV 		LANGUAGE en_US:zh_CN
ENV 		LC_ALL en_US.UTF-8

USER 		container
ENV  		USER=container HOME=/home/container

WORKDIR 	/home/container

COPY 		./entrypoint.sh /entrypoint.sh
COPY 		./wrapper.js /wrapper.js

CMD			[ "/bin/bash", "/entrypoint.sh" ]
