#!/usr/bin/env bash
set -euo pipefail

# renovate: datasource=github-releases depName=docker/compose
DOCKER_COMPOSE_VERSION=2.19.1
docker_compose_dir="$HOME/.docker/cli-plugins"
docker_compose_name="docker-compose"

mode="${1:-install}"

if [ "$mode" = "update" ]; then
    rm "$docker_compose_dir/$docker_compose_name"
else
    if [ -e "$docker_compose_dir/$docker_compose_name" ]; then
        echo "already installed docker-compose"
        exit 0
    fi
fi

mkdir -p "$docker_compose_dir"
curl -sLo "$docker_compose_dir/$docker_compose_name" https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-darwin-aarch64
chmod +x "$docker_compose_dir/$docker_compose_name"
