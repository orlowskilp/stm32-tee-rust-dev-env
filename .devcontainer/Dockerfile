# SPDX-License-Identifier: MIT

ARG VERSION=latest
ARG SDK_TARBALL_NAME=stm32mp2-openstlinux-6.6-yocto-scarthgap-mpu-v26.06.10
ARG SDK_TARBALL_FILE=SDK-x86_64-${SDK_TARBALL_NAME}.tar.gz
ARG SDK_RUST_ADDON_NAME=SDK-x86_64-stm32mp2-openstlinux-6.6-v26.06.10-addon-rust
ARG SDK_RUST_ADDON_FILE=${SDK_RUST_ADDON_NAME}.tar.gz
ARG SDK_TARBALL_PATH=..
ARG SDK_INSTALL_DIR=/opt/sdk

# Version is provided in devcontainer.json
FROM archlinux:${VERSION}

ARG SDK_INSTALL_DIR

# These are meant to be provided in devcontainer.json
ARG USERNAME
ARG SDK_TARBALL_NAME
ARG SDK_TARBALL_FILE
ARG SDK_RUST_ADDON_NAME
ARG SDK_RUST_ADDON_FILE
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
    patchelf \
    make \
    curl \
    which \
    diffutils \
    bash-completion \
    python \
    python-pip \
    aws-cli \
    github-cli \
    jq \
    bun \
    less \
    direnv \
    unzip \
    sudo && \
    rm /var/cache/pacman/pkg/*

RUN pip install cryptography \
    --break-system-packages \
    --root-user-action=ignore

# Create a non-root user set it up and roll over to it
RUN useradd -ms /bin/bash ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set up locale to install SDK correctly
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen

# Set up the SDK installation directory and ensure the non-root user has ownership.
RUN mkdir -p ${SDK_INSTALL_DIR} && \
    chown ${USERNAME}:${USERNAME} ${SDK_INSTALL_DIR}

USER ${USERNAME}
WORKDIR ${HOME_DIR}

# Set up environment variables for the OP-TEE SDK
ENV LANG="en_US.UTF-8" \
    LC_ALL="en_US.UTF-8"
COPY ${SDK_TARBALL_PATH}/${SDK_TARBALL_FILE} ${SDK_TARBALL_PATH}/${SDK_RUST_ADDON_FILE} ${HOME_DIR}/
# Install the OP-TEE SDK and Rust addon (see prerequisites in README.md)
RUN tar -xzf ${HOME_DIR}/${SDK_TARBALL_FILE} -C ${HOME_DIR} && \
    ${HOME_DIR}/${SDK_TARBALL_NAME}/sdk/*.sh -y -d ${SDK_INSTALL_DIR} && \
    rm -r ${HOME_DIR}/${SDK_TARBALL_FILE} ${HOME_DIR}/${SDK_TARBALL_NAME}
RUN source ${SDK_INSTALL_DIR}/environment-setup && \
    tar -xzf ${HOME_DIR}/${SDK_RUST_ADDON_FILE} -C ${HOME_DIR} && \
    yes | ${HOME_DIR}/${SDK_RUST_ADDON_NAME}/install.sh && \
    rm -r ${HOME_DIR}/${SDK_RUST_ADDON_FILE} ${HOME_DIR}/${SDK_RUST_ADDON_NAME}

# Install direnv
RUN echo eval '"$(direnv hook bash)"' >> ${HOME_DIR}/.bashrc
RUN mkdir -p ${HOME_DIR}/.local/bin

# Set environment variables for the devconctainer environment here
ENV PATH="${HOME_DIR}/.local/bin:${HOME_DIR}/.cargo/bin:${SDK_INSTALL_DIR}/sysroots/x86_64-ostl_sdk-linux/usr/bin/aarch64-ostl-linux:${PATH}" \
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
