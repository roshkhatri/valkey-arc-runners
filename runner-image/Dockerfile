FROM ghcr.io/actions/actions-runner:latest

RUN sudo apt-get update && sudo apt-get install -y \
    wget \
    build-essential \
    autoconf \
    automake \
    pkg-config \
    libssl-dev \
    tcl \
    tcl-dev \
    python3 \
    cmake \
    clang \
    valgrind \
    gcc-multilib \
    g++-multilib \
    libc6-dev-i386 \
    liblttng-ust-dev \
    libgtest-dev \
    libgmock-dev \
    git \
    curl \
    jq \
    && sudo apt-get clean \
    && sudo rm -rf /var/lib/apt/lists/*
