#!/bin/bash

# Mumble compile script.
# Runs on Debian 12

LOGFILE="/usr/src/mumble/build.log"

log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOGFILE
}

install_dep(){
    log "Installing dependencies..."
    apt update && apt -y install \
        build-essential \
        cmake \
        pkg-config \
        qtbase5-dev \
        qtchooser \
        qt5-qmake \
        qtbase5-dev-tools \
        qttools5-dev \
        qttools5-dev-tools \
        libqt5svg5-dev \
        libboost-dev \
        libssl-dev \
        libprotobuf-dev \
        protobuf-compiler \
        libprotoc-dev \
        libcap-dev \
        libxi-dev \
        libasound2-dev \
        libogg-dev \
        libsndfile1-dev \
        libspeechd-dev \
        libavahi-compat-libdnssd-dev \
        libxcb-xinerama0 \
        libzeroc-ice-dev \
        libpoco-dev \
        jq \
        python3 \
        curl \
        git

    if [[ $? -ne 0 ]]; then
        log "Failed to install dependencies"
        exit 1
    fi
    log "Dependencies installed successfully"
}

# Function to install g++-multilib on amd64
install_amd64_multilib() {
    apt -y install g++-multilib

    if [[ $? -ne 0 ]]; then
        log "Failed to install amd multilib dependency"
        exit 1
    fi

    log "Multilib AMD64 installed successfully"   
}

# Function to install multilib support on arm64
install_arm64_multilib() {
    apt -y install g++-multilib-x86-64-linux-gnu g++-aarch64-linux-gnu libc6-dev-armhf-cross
    
    if [[ $? -ne 0 ]]; then
        log "Failed to install amd multilib dependency"
        exit 1
    fi

    log "Multilib ARM64 installed successfully"   
}

clone_mumble(){
    log "Cloning the Mumble repository..."

    # Create the necessary directories
    mkdir -p /usr/src/mumble/git && cd /usr/src/mumble/git

    # Fetch the latest release tag from the GitHub API
    LATEST_TAG=$(curl -s "https://api.github.com/repos/mumble-voip/mumble/releases/latest" | jq -r .tag_name)
    if [[ $? -ne 0 || -z "$LATEST_TAG" ]]; then
        log "Failed to fetch the latest release tag"
        exit 1
    fi
    echo "The latest tag is: $LATEST_TAG" | tee -a $LOGFILE

    # Clone the repository
    echo "Running: git clone --branch \"$LATEST_TAG\" https://github.com/mumble-voip/mumble.git ."
    git clone --branch "$LATEST_TAG" https://github.com/mumble-voip/mumble.git .
    if [[ $? -ne 0 ]]; then
        log "Failed to clone the repository"
        exit 1
    fi

    # Clone the submodules
    git submodule update --init --recursive
    if [[ $? -ne 0 ]]; then
        log "Failed to update submodules"
        exit 1
    fi

    # Create and navigate to the build directory
    mkdir -p build && cd build

    echo "$LATEST_TAG" > latest_tag.txt

    # Run cmake with the specified options
    cmake -Dbundled-opus=OFF -Dclient=OFF -Dstatic=ON -DCMAKE_BUILD_TYPE=Release ..
    if [[ $? -ne 0 ]]; then
        log "CMake configuration failed"
        exit 1
    fi

    log "Repository cloned and configured successfully"
}

build_mumble(){
    log "Building Mumble server..."

    cd /usr/src/mumble/git/build

    echo "Using $(nproc) threads to build Mumble server" | tee -a $LOGFILE
    cmake --build . -j $(nproc)
    if [[ $? -ne 0 ]]; then
        log "Build failed"
        exit 1
    fi

    ls -la | tee -a $LOGFILE
    log "Build completed successfully"
}

# Install normal deps
install_dep

# Detect the architecture
ARCH=$(dpkg --print-architecture)

# Install ARCH specific deps
if [ "$ARCH" = "amd64" ]; then
    echo "Detected architecture: amd64"
    install_amd64_multilib
elif [ "$ARCH" = "arm64" ]; then
    echo "Detected architecture: arm64"
    install_arm64_multilib
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

clone_mumble
build_mumble
