#!/bin/bash

# SPDX-License-Identifier: MIT

# Remove the mnemonic file for the Docker GID
rm -f ${CONTAINER_WORKSPACE_FOLDER}/.devcontainer/docker_gid

# Set git username and email from environment variables if they are set
if [ -n "$GIT_USERNAME" ]; then
    git config --global user.name "$GIT_USERNAME"
fi
if [ -n "$GIT_EMAIL" ]; then
    git config --global user.email "$GIT_EMAIL"
fi

# Add the current directory to the list of safe directories for Git
# to avoid warnings when using Git in the container
git config --global --add safe.directory $(pwd)

# Suspend Git's message about moving to `main` as the default branch name
git config --global init.defaultBranch master

# Add some aliases for convenience
git config --global alias.tree 'log --all --graph --oneline --decorate'
git config --global alias.rh 'reset --hard @'
git config --global alias.fo 'fetch --prune --tags --force origin'
git config --global alias.co 'checkout'

# Install git hooks for the current repository if a .githooks directory exists
if [ -d ".githooks" ]; then
    git config --global core.hooksPath .githooks
fi

# Create a .envrc file in the workspace if it doesn't exist
if [ ! -f ${CONTAINER_WORKSPACE_FOLDER}/.envrc ]; then
    touch ${CONTAINER_WORKSPACE_FOLDER}/.envrc
fi

# Enable Rust autocompletion for the `rustup` command
mkdir -p ~/.cargo/completions
rustup completions bash >> ~/.cargo/completions/rustup
echo -e "\nsource ~/.cargo/completions/rustup\n" >> ~/.bashrc
 
# Enable AWS CLI autocompletion for the `aws` command
complete -C '/usr/bin/aws_completer' aws

# Copy the .aws directory from the workspace to the home directory
cp -r ${CONTAINER_WORKSPACE_FOLDER}/.aws ~/ 2>/dev/null || true

# Allow direnv to load environment variables every time a new shell is started
echo -e "\ndirenv allow ${CONTAINER_WORKSPACE_FOLDER}" >> ~/.bashrc
