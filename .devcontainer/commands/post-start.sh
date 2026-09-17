#!/bin/bash

# SPDX-License-Identifier: MIT

# Cheap trick to allow the container to access the host's Docker socket
DOCKER_SOCK=/var/run/docker.sock
sudo chmod 777 ${DOCKER_SOCK}

# Enforce ownership of local user files
sudo chown -R $(whoami):$(whoami) ~/.local
