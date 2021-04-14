#!/usr/bin/env bash
set -e

# Copyright (c) 2021 vesoft inc. All rights reserved.
#
# This source code is licensed under Apache 2.0 License,
# attached with Common Clause Condition 1.0, found in the LICENSES directory.

# Usage: install.sh

# Check Platform & Distribution

function print_banner {
	echo '.__   __.  _______ .______    __    __   __          ___            __    __  .______'
	echo '|  \ |  | |   ____||   _  \  |  |  |  | |  |        /   \          |  |  |  | |   _  \'
	echo '|   \|  | |  |__   |  |_)  | |  |  |  | |  |       /  ^  \   ______|  |  |  | |  |_)  |'
	echo '|  . `  | |   __|  |   _  <  |  |  |  | |  |      /  /_\  \ |______|  |  |  | |   ___/'
	echo '|  |\   | |  |____ |  |_)  | |  `--   | |   ----./  _____  \       |  `--   | |  |'
	echo '|__| \__| |_______||______/   \______/  |_______/__/     \__\       \______/  | _|'
}

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
	echo "$(source /etc/os-release && echo "$ID")"
}

# Detect Network Env

function nc_get_google_com {
	echo 2> /dev/null -n "GET / HTTP/1.0\r\n" | nc -v google.com 80 2>&1 | grep -q "http] succeeded" && echo "OK" || echo "NOK"
}

function cat_get_google_com {
	cat 2>/dev/null < /dev/null > /dev/tcp/google.com/80 && echo "OK" || echo "NOK"
}

function is_CN_NETWORK {
	case $PLATFORM in
		"x86_64-darwin"|"aarch64-darwin") internet_result=$(nc_get_google_com) ;;
		"x86_64-linux") internet_result=$(cat_get_google_com) ;;
	esac
	if [ $internet_result == "OK" ]; then
		false
	else
		true
	fi
}

# Install Dependencies(docker, Package Manager) with Network Env Awareness

function utility_exists {
	which $1 1>/dev/null 2>/dev/null && true || false
}

function install_package_ubuntu {
	sudo apt-get update -y
	sudo apt-get install -y $1
}

function install_package_centos {
	sudo yum -y update
	sudo yum -y install $1
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
	echo "[INFO] Installing Homebrew"
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
	case $PLATFORM in
		*arwin*) install_package_mac $1;;
		*inux*)  install_package_$(get_distribution) $1;;
    esac
}

function install_docker {
	# For both Linux and Darwin cases, CN network was considerred
	echo
	echo "[INFO] Starting Instlation of Docker"
	echo
	case $PLATFORM in
		*inux*)  utility_exists "wget" || install_package "wget" && sudo sh -c "$(wget https://get.docker.com -O -)" ;;
		*arwin*) install_package "docker" ;;
	esac
}

function install_docker_compose {
	# Only Linux is needed, for macOS, Docker Desktop comes with compose out of box
	COMPOSE_VERSION="1.29.0"
	echo
	echo "[INFO] Starting Instlation of Docker-Compose"
	echo
	sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
	sudo chmod +x /usr/local/bin/docker-compose
	sudo ln -s /usr/local/bin/docker-compose /sbin/docker-compose
}

function waiting_for_docker_engine_up {
	echo
	echo "[INFO] Waiting for Docker Engine to be up..."
	echo

	max_attempts=${MAX_ATTEMPTS-6}
	timer=${INIT_TIMER-4}

	while [[ $attempt < $max_attempts ]]
	do
		status=$(sudo docker ps 1>/dev/null 2>/dev/null && echo OK||echo NOK)
		if [[ "$status" == "OK" ]]; then
			break
		fi
		echo "[INFO] Docker Engine Check Attempt: ${attempt-0} Failed, Retrying in $timer Seconds..." 1>&2
		sleep $timer
		attempt=$(( attempt + 1 ))
		timer=$(( timer * 2 ))
	done

	if [[ "$status" != "OK" ]]; then
		echo "[ERROR] Failed to start Docker Engine, we are sorry about this :(" 1>&2
		exit 1
	fi
}

function start_docker {
	case $PLATFORM in
		*inux*)  sudo systemctl start docker ;;
		*arwin*) open -a Docker ;;
	esac
	waiting_for_docker_engine_up
}

function restart_docker {
	case $PLATFORM in
		*inux*)  sudo systemctl daemon-reload && sudo systemctl restart docker ;;
		*arwin*) osascript -e 'quit app "Docker"' && open -a Docker ;;
	esac
	waiting_for_docker_engine_up
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
	if ! utility_exists "git"; then
		install_package "git"
	fi
	if ! utility_exists "docker"; then
		install_docker
		if is_CN_NETWORK; then
			configure_docker_cn_mirror
			restart_docker
		fi
	else
		start_docker
	fi
	if ! utility_exists "docker-compose"; then
		install_docker_compose
	fi
	# TBD for other dependencies
}

# Check Ports States

function check_ports_availability {
	echo
	echo "[INFO] Checking Ports Availability"
	echo
	# TBD
}

# Deploy Nebula Graph

function waiting_for_nebula_graph_up {
	echo
	echo "[INFO] Waiting for all nebula-graph containers to be healthy..."
	echo
	expected_containers_count_str="9"
	healthy_containers_count_str=""
	max_attempts=${MAX_ATTEMPTS-6}
	timer=${INIT_TIMER-4}

	while [[ $attempt < $max_attempts ]]
	do
		healthy_containers_count_str=$(sudo docker ps --filter health=healthy |grep -v "CONTAINER ID"|wc -l|sed -e 's/^[[:space:]]*//')
		if [[ "$healthy_containers_count_str" == "$expected_containers_count_str" ]]; then
			break
		fi
		echo "[INFO] Nebula-Graph Containers Healthcheck Attempt: ${attempt-0} Failed, Retrying in $timer Seconds..." 1>&2
		sleep $timer
		attempt=$(( attempt + 1 ))
		timer=$(( timer * 2 ))
	done

	if [[ "$healthy_containers_count_str" != "$expected_containers_count_str" ]]; then
		echo "[ERROR] Failed to waiting for all containers to be healthy, check sudo docker ps for details." 1>&2
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
		echo "[WARN] $WOKRING_PATH/nebula-docker-compose already exists, existing repo will be reused" 1>&2
		echo
	fi
	cd nebula-docker-compose && git checkout v2.0.0 1>/dev/null 2>/dev/null
	export DOCKER_DEFAULT_PLATFORM=linux/amd64
	# FIXME, before we have ARM Linux images released, let's hardcode it inti x86_64
	sudo docker-compose pull
	sudo docker-compose up -d

	local MAX_ATTEMPTS=6
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
	cd nebula-web-docker && git checkout v2 1>/dev/null 2>/dev/null
	export DOCKER_DEFAULT_PLATFORM=linux/amd64
	# FIXME, before we have ARM Linux images released, let's hardcode it inti x86_64
	sudo docker-compose pull
	sudo docker-compose up -d
}

# Deploy Nebula Console

function install_nebula_graph_console {
	echo
	echo "[INFO] Pulling nebula-console docker image"
	echo
	sudo docker pull vesoft/nebula-console:v2.0.0-ga 1>/dev/null 2>/dev/null
	echo
	echo "[NOTE] You can add below alias if you like to access nebula graph console via nebula_graph_console 😁:"
	echo '>>> alias nebula_graph_console="export DOCKER_DEFAULT_PLATFORM=linux/amd64; docker run --rm -ti --network nebula-docker-compose_nebula-net --entrypoint=/bin/sh vesoft/nebula-console:v2.0.0-ga"'
	echo
}

# Create Uninstall Script

function create_uninstall_script {
	cat << EOF > $WOKRING_PATH/uninstall.sh
#!/usr/bin/env bash
# Copyright (c) 2021 vesoft inc. All rights reserved.
#
# This source code is licensed under Apache 2.0 License,
# attached with Common Clause Condition 1.0, found in the LICENSES directory.

# Usage: uninstall.sh

cd $WOKRING_PATH/nebula-web-docker && sudo docker-compose down
cd $WOKRING_PATH/nebula-docker-compose && sudo docker-compose down
sudo rm -fr $WOKRING_PATH/nebula-web-docker $WOKRING_PATH/nebula-docker-compose
EOF
	chmod +x $WOKRING_PATH/uninstall.sh
}

function main {
	print_banner

	WOKRING_PATH=$(pwd)
	PLATFORM=$(get_platform)
	CN_NETWORK=false
	if is_CN_NETWORK; then
		CN_NETWORK=true
	fi
	echo
	echo "[INFO] Ensuring Depedencies..."
	echo
	ensure_dependencies

	echo
	echo "[INFO] Boostraping Nebula Graph Cluster with Docker Compose..."
	echo

	install_nebula_graph

	echo
	echo "[INFO] Boostraping Nebula Graph Studio with Docker Compose..."
	echo

	install_nebula_graph_studio

	echo
	echo "[INFO] Preparing Nebula Graph Console Docker Image..."
	echo

	install_nebula_graph_console

	create_uninstall_script
}

main
