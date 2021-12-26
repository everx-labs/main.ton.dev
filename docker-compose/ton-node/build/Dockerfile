ARG RUST_VERSION=1.55.0

FROM ubuntu:18.04 as build

ARG RUST_VERSION

COPY ton-node /tonlabs/ton-node/
COPY ton-labs-node-tools /tonlabs/ton-labs-node-tools/
COPY tonos-cli /tonlabs/tonos-cli

# install deps
ENV TZ=Europe/Moscow
ENV PATH="/root/.cargo/bin:${PATH}"
#ENV RUST_BACKTRACE=1

RUN apt-get update && apt-get install -y curl gnupg2 && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ focal main restricted universe multiverse" >> /etc/apt/sources.list;\
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 871920D1991BC93C;\
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3B4FE6ACC0B21F32;\
    apt-get update && apt-get install -y \
    gpg \
    tar \
    cmake \
    build-essential \
    pkg-config \
    libssl-dev \
    libtool \
    m4 \
    automake \
    clang \
    git \
    libzstd-dev \
    libgoogle-perftools-dev

ENV ZSTD_LIB_DIR=/usr/lib/x86_64-linux-gnu

# rdkafka from confluent's repo
RUN curl https://packages.confluent.io/deb/5.5/archive.key | apt-key add;\
    echo "deb [arch=amd64] https://packages.confluent.io/deb/5.5 stable main" >> /etc/apt/sources.list;\
    apt-get update;\
    apt-get install -y librdkafka-dev;

# Get Rust
COPY rust_install.sh /tmp/rust_install.sh

RUN bash -c "/tmp/rust_install.sh ${RUST_VERSION}"

WORKDIR /tonlabs/ton-node
RUN #cargo update && cargo build --release --features "metrics,compression"
RUN cargo update && cargo build --release --features "metrics"

WORKDIR /tonlabs/ton-labs-node-tools
RUN cargo update && cargo build --release

WORKDIR /tonlabs/tonos-cli
RUN cargo update && cargo build --release

FROM ubuntu:18.04

ARG RUST_VERSION

ENV TZ=Europe/Moscow

RUN apt-get update && apt-get install -y curl gnupg2
RUN curl https://packages.confluent.io/deb/5.5/archive.key | apt-key add
RUN echo "deb [arch=amd64] https://packages.confluent.io/deb/5.5 stable main" >> /etc/apt/sources.list
RUN echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ focal main restricted universe multiverse" >> /etc/apt/sources.list;\
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 871920D1991BC93C;\
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3B4FE6ACC0B21F32;\
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone;\
    apt-get update && apt-get install -y \
    librdkafka1 \
    build-essential \
    cmake \
    cron \
    git \
    gdb \
    gpg \
    jq \
    tar \
    vim \
    tcpdump \
    netcat \
    python3 \
    python3-pip \
    wget \
    libzstd-dev \
    libgoogle-perftools-dev

ENV ZSTD_LIB_DIR=/usr/lib/x86_64-linux-gnu

# Get Rust
COPY rust_install.sh /tmp/rust_install.sh

RUN bash -c "/tmp/rust_install.sh ${RUST_VERSION}"

RUN mkdir -p /ton-node/tools
#COPY --from=build /tonlabs/ton-node/target/release/ton_node /ton-node/ton_node_no_kafka_compression
COPY --from=build /tonlabs/ton-node/target/release/ton_node /ton-node/ton_node_no_kafka
COPY --from=build /tonlabs/ton-labs-node-tools/target/release/console /ton-node/tools/
COPY --from=build /tonlabs/ton-labs-node-tools/target/release/keygen /ton-node/tools/
COPY --from=build /tonlabs/tonos-cli/target/release/tonos-cli /ton-node/tools/
