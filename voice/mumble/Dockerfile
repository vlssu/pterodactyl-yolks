FROM --platform=$TARGETOS/$TARGETARCH debian:bookworm-slim AS builder

# Copy and run the build script
COPY build.sh /build.sh
RUN chmod +x /build.sh
RUN cd / && ./build.sh

FROM --platform=$TARGETOS/$TARGETARCH debian:bookworm-slim

# Create necessary directories
RUN mkdir -p /usr/local/bin /usr/local/share/mumble

# Copy the built Mumble server binary and the latest tag file and the build log from the builder stage
COPY --from=builder /usr/src/mumble/git/build/mumble-server /usr/local/bin/mumble-server
COPY --from=builder /usr/src/mumble/git/build/latest_tag.txt /usr/local/share/mumble/latest_tag.txt
COPY --from=builder /usr/src/mumble/build.log /usr/local/share/mumble/build.log

# Install runtime dependencies
RUN apt update \
    && apt -y install curl tar tzdata file ca-certificates sqlite3 iproute2 tini \
    && useradd -m -d /home/container container

# Needed packages to run the mumble server
RUN apt -y install libqt5sql5 libqt5sql5-sqlite libavahi-compat-libdnssd-dev libqt5dbus5 libzeroc-ice-dev libprotobuf-dev qtbase5-dev qtbase5-dev-tools

# Set up user and working directory
USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

# Set the stop signal
STOPSIGNAL SIGINT

# Copy and set up the entrypoint script
COPY --chown=container:container ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Define entrypoint and command
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/entrypoint.sh"]
