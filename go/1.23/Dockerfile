FROM        --platform=$TARGETOS/$TARGETARCH golang:1.23-alpine


RUN         apk add --update --no-cache ca-certificates tzdata icu-data-full \
				&& adduser -D -h /home/container container

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

COPY        ./../entrypoint.sh /entrypoint.sh
CMD         [ "/bin/ash", "/entrypoint.sh" ]
