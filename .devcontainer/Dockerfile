ARG VERSION=latest
ARG SDK_TARBALL_NAME=stm32mp2-openstlinux-6.6-yocto-scarthgap-mpu-v26.06.10
ARG SDK_TARBALL_FILE=SDK-x86_64-${SDK_TARBALL_NAME}.tar.gz
ARG SDK_TARBALL_PATH=..
ARG SDK_INSTALL_DIR=/opt/sdk

# Version is provided in devcontainer.json
FROM archlinux:${VERSION}

ARG SDK_INSTALL_DIR

# These are meant to be provided in devcontainer.json
ARG USERNAME
ARG SDK_TARBALL_NAME
ARG SDK_TARBALL_FILE
ARG SDK_TARBALL_PATH

# These are the default values for the build arguments. Don't edit
# unless you know what you're doing.
ARG HOME_DIR=/home/${USERNAME}

# Install dependencies and clean up the cache
RUN pacman -Suy --disable-sandbox --noconfirm \
    pkg-config \
    git \
    gcc \
    aarch64-linux-gnu-gcc \
    musl \
    musl-aarch64 \
    make \
    curl \
    which \
    diffutils \
    bash-completion \
    python \
    aws-cli \
    github-cli \
    jq \
    bun \
    less \
    direnv \
    unzip \
    sudo && \
    rm /var/cache/pacman/pkg/*

# Create a non-root user set it up and roll over to it
RUN useradd -ms /bin/bash ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen

RUN mkdir -p ${SDK_INSTALL_DIR} && \
    chown ${USERNAME}:${USERNAME} ${SDK_INSTALL_DIR}

USER ${USERNAME}
WORKDIR ${HOME_DIR}

# Set up environment variables for the OP-TEE SDK
ENV PATH="${PATH}:${HOME_DIR}/.local/bin" \
    LANG="en_US.UTF-8" \
    LC_ALL="en_US.UTF-8"
COPY ${SDK_TARBALL_PATH}/${SDK_TARBALL_FILE} ${HOME_DIR}/${SDK_TARBALL_FILE}
RUN tar -xzf ${HOME_DIR}/${SDK_TARBALL_FILE} -C ${HOME_DIR} && \
    ${HOME_DIR}/${SDK_TARBALL_NAME}/sdk/*.sh -y -d ${SDK_INSTALL_DIR} && \
    rm -r ${HOME_DIR}/${SDK_TARBALL_FILE} ${HOME_DIR}/${SDK_TARBALL_NAME}

# Install direnv
RUN echo eval '"$(direnv hook bash)"' >> ${HOME_DIR}/.bashrc
RUN mkdir -p ${HOME_DIR}/.local/bin

# Set environment variables for the devconctainer environment here
ENV PATH="${PATH}:${HOME_DIR}/.cargo/bin" \
    CARGO_TERM_COLOR="always"

# Install Rust
RUN curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh -s -- -y && \
    cargo install \
        cargo-llvm-cov && \
    rustup component add \
        rust-analysis \
        rust-analyzer

# Install starship
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes && \
    starship init bash >> ~/.bashrc

# Install OpenCode
RUN curl -fsSL https://opencode.ai/install | bash

# Install dprint
RUN curl -fsSL https://dprint.dev/install.sh | sh && \
    mv ${HOME_DIR}/.dprint/bin/dprint ${HOME_DIR}/.local/bin/ && \
    rm -rf ${HOME_DIR}/.dprint
