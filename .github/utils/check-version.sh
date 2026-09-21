#!/bin/bash
# SPDX-License-Identifier: MIT
set -e

PKG_VERSION=v$(grep '^version =' Cargo.toml | head -1 | awk -F'"' '{print $2}')
README_VERSION=v$(grep 'version' README.md | head -1 | awk -F'-v' '{print $2}' | awk -F'-' '{print $1}')
if [[ "$PKG_VERSION" != "$README_VERSION" ]]; then
  echo -e "\e[0;31mVersion mismatch:\e[0m"
  {
  printf "\e[0;35m%s\e[0m version:\t\e[0;34m(%s)\e[0m\n" "Cargo.toml" "$PKG_VERSION"
  printf "\e[0;35m%s\e[0m version:\t\e[0;34m(%s)\e[0m\n" "README.md" "$README_VERSION"
} | column -s $'\t' -t
  exit 1
fi

TAG_REF_PREFIX="refs/tags/"
if [[ $(echo $GITHUB_REF | grep $TAG_REF_PREFIX | wc -l) -lt 1 ]]; then
  echo -e "The event is not a tag. Skipping git tag version check...\n"
  echo -e "\e[0;32mVersions matching:\e[0m"
  {
  printf "\e[0;35m%s\e[0m version:\t\e[0;34m(%s)\e[0m\n" "Cargo.toml" "$PKG_VERSION"
  printf "\e[0;35m%s\e[0m version:\t\e[0;34m(%s)\e[0m\n" "README.md" "$README_VERSION"
} | column -s $'\t' -t
  exit 0
fi

TAG_VERSION=${GITHUB_REF#$TAG_REF_PREFIX}
if [[ "$PKG_VERSION" != "$TAG_VERSION" ]]; then
  echo -e "\e[0;31mVersion mismatch:\e[0m"
  {
  printf "\e[0;35m%s\e[0m version:\t\e[0;34m(%s)\e[0m\n" "Cargo.toml" "$PKG_VERSION"
  printf "\e[0;35m%s\e[0m version:\t\e[0;34m(%s)\e[0m\n" "git tag" "$TAG_VERSION"
} | column -s $'\t' -t
  exit 1
fi

echo -e "\e[0;32mAll versions matching:\e[0m"
{
  printf "\e[0;35m%s\e[0m version:\t\e[0;34m(%s)\e[0m\n" "Cargo.toml" "$PKG_VERSION"
  printf "\e[0;35m%s\e[0m version:\t\e[0;34m(%s)\e[0m\n" "README.md" "$README_VERSION"
  printf "\e[0;35m%s\e[0m version:\t\e[0;34m(%s)\e[0m\n" "git tag" "$TAG_VERSION"
} | column -s $'\t' -t