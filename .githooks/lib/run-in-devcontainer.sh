#!/usr/bin/env bash

# SPDX-License-Identifier: MIT

set -euo pipefail

GREEN="\e[0;32m"
RED="\e[0;31m"
YELLOW="\e[0;33m"
NC="\e[0m" # No Color

HOOKS="${GREEN}[hooks]${NC}"

DEVCONTAINER_JSON_PATH=".devcontainer/devcontainer.json"
DEFAULT_DEV_CONTAINER_NAME=$(grep "\--name" "$DEVCONTAINER_JSON_PATH" | awk -F '=' '{ print $2 }' | tr -d '",' )
DEFAULT_WORKSPACE_DIR="$(grep "workspaceFolder" "$DEVCONTAINER_JSON_PATH" | awk -F ':' '{ print $2 }' | xargs | tr -d ',')"

resolve_dev_container_name() {
  local configured_name
  configured_name="${DEV_CONTAINER_NAME:-$DEFAULT_DEV_CONTAINER_NAME}"

  if docker ps --format '{{.Names}}' | grep -Fxq "$configured_name"; then
    echo "$configured_name"
    return 0
  fi

  # Fallback: detect by VS Code devcontainer label for this repository path.
  local local_path
  local_path="$(pwd -P)"
  docker ps --filter "label=devcontainer.local_folder=${local_path}" --format '{{.Names}}' | head -n 1
}

run_in_devcontainer() {
  if ! command -v docker >/dev/null 2>&1; then
    echo -e "${HOOKS} ${RED}docker is required on host to run checks in the dev container.${NC}" >&2
    return 1
  fi

  local container_name
  container_name="$(resolve_dev_container_name)"
  if [[ -z "$container_name" ]]; then
    echo -e "${HOOKS} ${RED}could not find a running dev container for this repository.${NC}" >&2
    echo -e "${HOOKS} start the dev container first, or set DEV_CONTAINER_NAME explicitly." >&2
    return 1
  fi

  local cmd
  cmd="$1"
  local workspace_dir
  workspace_dir="${DEV_CONTAINER_WORKSPACE:-$DEFAULT_WORKSPACE_DIR}"

  local env_args=()
  [[ -n "${AWS_ACCESS_KEY_ID:-}" ]] && env_args+=( -e "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}" )
  [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]] && env_args+=( -e "AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}" )
  [[ -n "${AWS_SESSION_TOKEN:-}" ]] && env_args+=( -e "AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN}" )
  [[ -n "${AWS_REGION:-}" ]] && env_args+=( -e "AWS_REGION=${AWS_REGION}" )

  # Load .envrc inside the container for the same shell that runs the command.
  # Prefer direnv when available; fallback to sourcing .envrc directly.
  local in_container_prefix
  in_container_prefix='if [[ -f .envrc ]]; then if command -v direnv >/dev/null 2>&1; then eval "$(direnv export bash)"; else set -a; source ./.envrc; set +a; fi; fi'

  docker exec -i "${env_args[@]}" "$container_name" bash -lc "cd ${workspace_dir} && ${in_container_prefix} && ${cmd}"
}