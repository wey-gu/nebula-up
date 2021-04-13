#! /usr/bin/env bash
set -e

# Copyright (c) 2019 vesoft inc. All rights reserved.
#
# This source code is licensed under Apache 2.0 License,
# attached with Common Clause Condition 1.0, found in the LICENSES directory.

# Usage: install.sh [--version/-v 2.0.0] [--no-web] [--no-console]

# Check Platform & Distribution

function get_platform {
	case $(uname -ms) in
		"Darwin x86_64") platform="x86_64-darwin" ;;
		"Darwin arm64")  platform="aarch64-darwin" ;;
		"Linux x86_64")  platform="x86_64-linux" ;;
		*)               platform="unknown-platform" ;;
	esac
	echo $platform
}

function get_distribution {
	echo "$(source /etc/os-release && echo "$ID" || true)"
}

# Detect Network Env

function nc_get_google_com {
	echo -n "GET / HTTP/1.0\r\n" | nc -v google.com 80 2>&1 | grep -q "http] succeeded" && echo "OK" || true
}

function cat_get_google_com {
	cat < /dev/null > /dev/tcp/google.com/80 && echo "OK" || true
}

function is_CN_NETWORK {
	case $PLATFORM in
		"x86_64-darwin"|"x86_64-linux") internet_result=$(nc_get_google_com) ;;
		"Linux x86_64") internet_result=$(cat_get_google_com) ;;
	esac
	if [ $internet_result == "OK" ]; then
		false
	else
		true
	fi
}

# Install Dependencies(docker, Package Manager) with Network Env Awareness

function utility_exists {
	which $1 && true || false
}

function install_package_ubuntu {
	# $1 string: package name
	# $2 bool:   if CN network
	sudo apt-get update
	sudo apt-get install -y $1
}

function install_package_centos {
	# $1 string: package name
	# $2 bool:   if CN network
	sudo apt-get update
	sudo yum install -y $1
}

function install_homebrew {
	if is_CN_NETWORK; then
		# https://mirrors.tuna.tsinghua.edu.cn/help/homebrew/
		BREW_TYPE="homebrew"
		HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
        HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/${BREW_TYPE}-core.git"
        HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/${BREW_TYPE}-bottles"
    fi
    echo
    echo Installing Homebrew
    echo
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

function install_package_mac {
	if ! utility_exists "brew"; then
		install_homebrew
	fi
	brew install $1
}

function install_package {
	# $1 string: package name
	# $2 bool:   if CN network
	case $PLATFORM in
		*arwin*) install_package_mac $1;;
		*inux*)  install_package_$(get_distribution) $1;;
    esac
}

function install_docker {
	# For both Linux and Darwin cases, CN network was considerred
	echo
	echo "Starting Instlation of Docker"
	echo
	case $PLATFORM in
		*inux*)  utility_exists "wget" || install_package "wget" && sudo sh -c "$(wget https://get.docker.com -O -)" ;;
		*arwin*) install_package "docker" ;;
	esac
}

function start_docker {
	case $PLATFORM in
		*inux*)  sudo systemctl start docker ;;
		*arwin*) open -a Docker ;;
	esac
}

function restart_docker {
	case $PLATFORM in
		*inux*)  sudo systemctl daemon-reload && sudo systemctl restart docker ;;
		*arwin*) osascript -e 'quit app "Docker"' && open -a Docker ;;
	esac
}

function configure_docker_cn_mirror {
	# FIXME: let's override it as it's assumed docker was installed by this script, while it's good to actually edit the json file
	case $PLATFORM in
		*inux*)  DOCKER_CONF_PATH="/etc/docker" ;;
		*arwin*) DOCKER_CONF_PATH="$HOME/.docker" ;;
	esac
	cat << EOF > ${DOCKER_CONF_PATH}/daemon.json
{
  "registry-mirrors": [
    "https://hub-mirror.c.163.com"
  ]
}
EOF
}

function ensure_dependencies {
	if ! utility_exists "docker"; then
		install_docker
		if is_CN_NETWORK; then
			configure_docker_cn_mirror
			restart_docker
		fi
	else
		start_docker
	fi
	# TBD for other dependencies
}

# Check Ports States

function check_ports_availability {
	echo
	echo "Checking Ports Availability"
	echo
	# TBD
}

# Deploy Nebula Graph

function waiting_for_nebula_graph_up {
	echo
	echo "Waiting for all nebula-graph containers to be healthy..."
	echo
	expected_containers_count_str="9"
	healthy_containers_count_str=""
	max_attempts=${MAX_ATTEMPTS-5}
	timer=${INIT_TIMER-4}

	while [[ $attempt < $max_attempts ]]
	do
		healthy_containers_count_str=$(docker ps --filter health=healthy |grep -v "CONTAINER ID"| wc -l)
		if [[ $healthy_containers_count_str == $expected_containers_count_str ]]
		then
			break
		fi
		echo "Healthcheck Attempt: ${attempt-0} Failed, Retrying in $timer Seconds..." 1>&2
		sleep $timer
		attempt=$(( attempt + 1 ))
		timer=$(( timer * 2 ))
	done

	if [[ $healthy_containers_count_str != $expected_containers_count_str ]]; then
		echo "[ERROR] Failed to waiting for all containers to be healthy, check docker ps for details." 1>&2
	fi
}

function install_nebula_graph {
	# TBD, considerring create gitee mirror for git repo? if is_CN_NETWORK is true.
	# https://github.com/vesoft-inc/nebula-docker-compose
	cd $WOKRING_PATH
	if [ ! -d "$WOKRING_PATH/nebula-docker-compose" ]; then
		git clone --branch v2.0.0 https://github.com/vesoft-inc/nebula-docker-compose.git
	else
		echo
		echo "[WARN] $WOKRING_PATH/nebula-docker-compose already exists, existing repo will be reused"
		echo
	fi
	cd nebula-docker-compose && git checkout v2.0.0
	export DOCKER_DEFAULT_PLATFORM=linux/amd64
	# FIXME, before we have ARM Linux images released, let's hardcode it inti x86_64
	docker-compose pull
	docker-compose up -d

	local MAX_ATTEMPTS=5
	local INIT_TIMER=4
	waiting_for_nebula_graph_up
}

# Deploy Nebula Graph Studio


function install_nebula_graph_studio {
	cd $WOKRING_PATH
	if [ ! -d "$WOKRING_PATH/nebula-web-docker" ]; then
		git clone --branch v2 https://github.com/vesoft-inc/nebula-web-docker.git
	else
		echo
		echo "[WARN] $WOKRING_PATH/nebula-web-docker already exists, existing repo will be reused"
		echo
	fi
	cd nebula-web-docker && git checkout v2
	export DOCKER_DEFAULT_PLATFORM=linux/amd64
	# FIXME, before we have ARM Linux images released, let's hardcode it inti x86_64
	docker-compose pull
	docker-compose up -d
}

# Deploy Nebula Console

function install_nebula_graph_console {
	echo
	echo "Pulling nebula-console docker image"
	echo
	docker pull vesoft/nebula-console:v2.0.0-ga
	echo
	echo "Add below alias if you like to:"
	echo 'alias nebula_graph_console="export DOCKER_DEFAULT_PLATFORM=linux/amd64; docker run --rm -ti --network nebula-docker-compose_nebula-net --entrypoint=/bin/sh vesoft/nebula-console:v2.0.0-ga"'
	echo
}

function main {
	WOKRING_PATH=$(pwd)
	PLATFORM=$(get_platform)
	CN_NETWORK=false
	if is_CN_NETWORK; then
		CN_NETWORK=true
	fi
	ensure_dependencies

	install_nebula_graph

	install_nebula_graph_studio

	install_nebula_graph_console
}

main
