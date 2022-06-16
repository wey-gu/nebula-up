#!/usr/bin/env bash
set -e

# Copyright (c) 2021 vesoft inc. All rights reserved.
#
# This source code is licensed under Apache 2.0 License,


# Usage: install.sh

# Check Platform & Distribution

function logger_info {
	echo
	echo " ℹ️   " $1
}

function logger_warn {
	echo
	echo " ⚠️   " $1 1>&2
}

function logger_error {
	echo
	echo -e " ❌  " $1 1>&2
	echo "      Exiting, Stack Trace: ${executing_function-${FUNCNAME[*]}}"
	cd $CURRENT_PATH
	print_footer_error
	exit 1
}

function logger_ok {
	echo " ✔️   " $1
}

function excute_step {
	executing_function=$1
	$1 && logger_ok "$1 Finished" || logger_error "Failed in Step: $(echo ${executing_function//_/ })"
}

function print_banner {
	echo '┌──────────────────────────────────────────────────────────────────────────────────────────┐'
	echo '│ 🌌 Nebula-Graph Playground is on the way...                                              │'
	echo '├──────────────────────────────────────────────────────────────────────────────────────────┤'
	echo '│.__   __.  _______ .______    __    __   __          ___            __    __  .______     │'
	echo '│|  \ |  | |   ____||   _  \  |  |  |  | |  |        /   \          |  |  |  | |   _  \    │'
	echo '│|   \|  | |  |__   |  |_)  | |  |  |  | |  |       /  ^  \   ______|  |  |  | |  |_)  |   │'
	echo '│|  . `  | |   __|  |   _  <  |  |  |  | |  |      /  /_\  \ |______|  |  |  | |   ___/    │'
	echo '│|  |\   | |  |____ |  |_)  | |  `--   | |   ----./  _____  \       |  `--   | |  |        │'
	echo '│|__| \__| |_______||______/   \______/  |_______/__/     \__\       \______/  | _|        │'
	echo '└──────────────────────────────────────────────────────────────────────────────────────────┘'
}

function get_platform {
	case $(uname -ms) in
		"Darwin x86_64") platform="x86_64-darwin" ;;
		"Darwin arm64")  platform="aarch64-darwin" ;;
		"Linux x86_64")  platform="x86_64-linux" ;;
		"Linux aarch64") platform="aarch64-linux" ;;
		*)               platform="unknown-platform" ;;
	esac
	echo $platform
}

function is_linux {
	if [[ $(uname -s) == Linux ]]; then
		true
	else
		false
	fi
}

function is_mac {
	if [[ $(uname -s) == Darwin ]]; then
		true
	else
		false
	fi
}

function verify_sudo_permission {
	logger_info "Verifying user's sudo Permission..."
	sudo true
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
		"x86_64-linux"|"aarch64-linux") internet_result=$(cat_get_google_com) ;;
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
	logger_info "Installing Homebrew"
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
	logger_info "Starting Instlation of Docker"
	case $PLATFORM in
		*inux*)  sudo sh -c "$(wget https://get.docker.com -O -)" ;;
		*arwin*) install_package "docker" ;;
	esac
}

function install_docker_compose {
	# Only Linux is needed, for macOS, Docker Desktop comes with compose out of box
	COMPOSE_VERSION="v2.6.0"
	logger_info "Starting Instlation of Docker-Compose"
	sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
	sudo chmod +x /usr/local/bin/docker-compose
	sudo ln -s /usr/local/bin/docker-compose /sbin/docker-compose
}

function waiting_for_docker_engine_up {
	logger_info "Waiting for Docker Engine to be up..."

	local max_attempts=${MAX_ATTEMPTS-6}
	local timer=${INIT_TIMER-4}
	local attempt=1

	while [[ $attempt < $max_attempts ]]
	do
		status=$(sudo docker ps 1>/dev/null 2>/dev/null && echo OK||echo NOK)
		if [[ "$status" == "OK" ]]; then
			logger_ok "docker engine is up."
			break
		fi
		logger_info "Docker Engine Check Attempt: ${attempt-0} Failed, Retrying in $timer Seconds..."
		sleep $timer
		attempt=$(( attempt + 1 ))
		timer=$(( timer * 2 ))
	done

	if [[ "$status" != "OK" ]]; then
		logger_error "Failed to start Docker Engine, we are sorry about this :("
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
	sudo bash -c "cat > ${DOCKER_CONF_PATH}/daemon.json" << EOF
{
  "registry-mirrors": [
    "https://hub-mirror.c.163.com"
  ]
}
EOF
}

function ensure_docker_permission {
	logger_info "Ensuring Linux Docker Permission"
	if is_linux; then
		sudo groupadd docker --force || \
			logger_error "failed during: groupadd docker"
		sudo usermod -aG docker $USER || \
			logger_error "failed during: sudo usermod -aG docker $USER"
		newgrp docker <<EOF || \
			logger_error "failed during: newgrp docker"
EOF
	fi
	docker ps 1>/dev/null 2>/dev/null || \
		logger_error "Ensuring docker Permission Failed, please try: \n	\
				option 0: linux: execute this command and retry:\n		$ newgrp docker\n	\
				option 1: linux: relogin current shell session and retry install.sh \n \
				option 2: macOS: start Docker Desktop yourself and retry."
}

function ensure_dependencies {
	if ! utility_exists "git"; then
		install_package "git"
	fi
	if ! utility_exists "wget"; then
	  install_package "wget"
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
	ensure_docker_permission
	if ! utility_exists "docker-compose"; then
		install_docker_compose
	fi
	# TBD for other dependencies
}

# Check Ports States

function check_ports_availability {
	logger_info "Checking Ports Availability"
	# TBD
}

# Deploy Nebula Graph

function waiting_for_nebula_graph_up {
	logger_info "Waiting for all nebula-graph containers to be healthy..."
	expected_containers_count_str="9"
	healthy_containers_count_str=""
	local max_attempts=${MAX_ATTEMPTS-6}
	local timer=${INIT_TIMER-4}
	local attempt=1
    cd $WOKRING_PATH/nebula-docker-compose
	while [[ $attempt < $max_attempts ]]
	do
		healthy_containers_count_str=$(docker-compose ps --filter health=healthy | grep 'Up ('|wc -l|sed -e 's/^[[:space:]]*//')
		if [[ "$healthy_containers_count_str" == "$expected_containers_count_str" ]]; then
			logger_ok "all nebula-graph containers are healthy."
			break
		fi
		logger_info "Nebula-Graph Containers Healthcheck Attempt: ${attempt-0} Failed, Retrying in $timer Seconds..."
		sleep $timer
		attempt=$(( attempt + 1 ))
		timer=$(( timer * 2 ))
	done

	if [[ "$healthy_containers_count_str" != "$expected_containers_count_str" ]]; then
		logger_warn "Failed to waiting for all containers to be healthy, check docker ps for details."
	fi
}

function install_nebula_graph {
	# TBD, considerring create gitee mirror for git repo? if is_CN_NETWORK is true.
	# https://github.com/vesoft-inc/nebula-docker-compose
	docker network create nebula-net > /dev/null 2>&1 || true
	cd $WOKRING_PATH
	if [ ! -d "$WOKRING_PATH/nebula-docker-compose" ]; then
		git clone --branch $NEBULA_VERSION https://github.com/vesoft-inc/nebula-docker-compose.git
		grep "external" nebula-docker-compose/docker-compose.yaml > /dev/null 2>&1 || \
			echo "    external: true" >> nebula-docker-compose/docker-compose.yaml
	else
		logger_warn "$WOKRING_PATH/nebula-docker-compose already exists, existing repo will be reused"
		fi
	cd nebula-docker-compose && git checkout $NEBULA_VERSION 1>/dev/null 2>/dev/null
	# FIXME, before we have ARM Linux images released, let's hardcode it inti x86_64
	docker-compose pull
	docker-compose up -d

}

# Deploy Nebula Graph Studio


function install_nebula_graph_studio {
	cd $WOKRING_PATH
	if [ -d "$WOKRING_PATH/nebula-graph-studio-v$STUDIO_VERSION" ]; then
		rm -fr $WOKRING_PATH/nebula-graph-studio-v$STUDIO_VERSION
	fi
	if [ $STUDIO_VERSION = "3.1.0" ]; then
		VERSION_FOLDER=""
	else
		VERSION_FOLDER="$STUDIO_VERSION/"
	fi
	wget https://oss-cdn.nebula-graph.com.cn/nebula-graph-studio/${VERSION_FOLDER}nebula-graph-studio-v$STUDIO_VERSION.tar.gz 1>/dev/null 2>/dev/null
	mkdir nebula-graph-studio-v$STUDIO_VERSION && tar -zxvf nebula-graph-studio-v$STUDIO_VERSION.tar.gz -C nebula-graph-studio-v$STUDIO_VERSION 1>/dev/null 2>/dev/null
	grep "external" nebula-graph-studio-v$STUDIO_VERSION/docker-compose.yml > /dev/null 2>&1 || \
		echo "    external: true" >> nebula-graph-studio-v$STUDIO_VERSION/docker-compose.yml
	sed -i 's/nebula-web/nebula-net/g' nebula-graph-studio-v$STUDIO_VERSION/docker-compose.yml > /dev/null 2>&1
	cd nebula-graph-studio-v$STUDIO_VERSION
	export DOCKER_DEFAULT_PLATFORM=linux/amd64
	# FIXME, before we have ARM Linux images released, let's hardcode it inti x86_64
	docker-compose pull
	docker-compose up -d
}

# Deploy Nebula Console

function install_nebula_graph_console {
	logger_info "Pulling nebula-console docker image"
	docker pull vesoft/nebula-console:${CONSOLE_VERSION} 1>/dev/null 2>/dev/null

	sudo bash -c "cat > $WOKRING_PATH/console.sh" << EOF
#!/usr/bin/env bash
# Copyright (c) 2021 vesoft inc. All rights reserved.
#
# This source code is licensed under Apache 2.0 License,


# Usage: console.sh or console.sh -e "SHOW HOSTS"

export DOCKER_DEFAULT_PLATFORM=linux/amd64;
sudo docker run --rm -ti --network nebula-net --volume $WOKRING_PATH:/root vesoft/nebula-console:${CONSOLE_VERSION} -addr graphd -port 9669 -u root -p nebula "\$@"
EOF
	sudo chmod +x $WOKRING_PATH/console.sh
	logger_info "Created console.sh 😁"

	sudo bash -c "cat > $WOKRING_PATH/load-basketballplayer-dataset.sh" << EOF
#!/usr/bin/env bash
# Copyright (c) 2021 vesoft inc. All rights reserved.
#
# This source code is licensed under Apache 2.0 License,


# Usage: load-basketballplayer-dataset.sh

export DOCKER_DEFAULT_PLATFORM=linux/amd64;
sudo docker run --rm -ti --network nebula-net vesoft/nebula-console:${CONSOLE_VERSION} -addr graphd -port 9669 -u root -p nebula -e ":play basketballplayer"
EOF
	sudo chmod +x $WOKRING_PATH/load-basketballplayer-dataset.sh
	logger_info "Created load-basketballplayer-dataset.sh 😁"

}

# Create Uninstall Script

function create_uninstall_script {
	sudo bash -c "WOKRING_PATH=$WOKRING_PATH;cat > $WOKRING_PATH/uninstall.sh" << EOF
#!/usr/bin/env bash
# Copyright (c) 2021 vesoft inc. All rights reserved.
#
# This source code is licensed under Apache 2.0 License,


# Usage: uninstall.sh

echo " ℹ️   Cleaning Up Files under $WOKRING_PATH..."
cd $WOKRING_PATH/nebula-graph-studio-v$STUDIO_VERSION 2>/dev/null
docker-compose down 2>/dev/null
cd $WOKRING_PATH/nebula-up/dashboard 2>/dev/null
docker-compose down 2>/dev/null
cd $WOKRING_PATH/nebula-up/spark 2>/dev/null
docker-compose down 2>/dev/null
cd $WOKRING_PATH/nebula-up/backup_restore 2>/dev/null
docker-compose down 2>/dev/null
sudo docker volume rm backup_restore_data1-1 backup_restore_data1-2 backup_restore_data2-1 backup_restore_data2-2 2>/dev/null
sudo docker volume rm spark_hadoop_datanode spark_hadoop_historyserver spark_hadoop_namenode 2>/dev/null
cd $WOKRING_PATH/nebula-docker-compose 2>/dev/null
docker-compose down 2>/dev/null

sudo rm -fr $WOKRING_PATH/nebula-graph-studio-v$STUDIO_VERSION $WOKRING_PATH/nebula-docker-compose $WOKRING_PATH/nebula-up 2>/dev/null
echo "┌────────────────────────────────────────┐"
echo "│ 🌌 Nebula-Up Uninstallation Finished   │"
echo "└────────────────────────────────────────┘"
EOF
	sudo chmod +x $WOKRING_PATH/uninstall.sh
}

function install_nebula_graph_dashboard {
	# if DASHBOARD is not true, then skip, else continue to install.
	if [ "$DASHBOARD" != "true" ]; then
		logger_info "Skip nebula-graph-dashboard installation in current mode: $MODE"
		return
	fi
	# if DASHBOARD is true, then continue to install.
	logger_info "Installing nebula-graph-dashboard..."
	cd $WOKRING_PATH
	if [ ! -d "$WOKRING_PATH/nebula-up" ]; then
		git clone https://github.com/wey-gu/nebula-up.git
	else
		logger_warn "$WOKRING_PATH/nebula-up already exists, existing repo will be reused"
	fi
	cd nebula-up && git stash 1>/dev/null 2>/dev/null && git pull 1>/dev/null 2>/dev/null
	cd dashboard
	docker-compose pull
	docker-compose up -d

}

function install_nebula_graph_spark {
	# if SPARK is not true, then skip, else continue to install.
	if [ "$SPARK" != "true" ]; then
		logger_info "Skip Spark env installation in current mode: $MODE"
		return
	fi
	# if SPARK is true, then continue to install.
	logger_info "Installing Nebula Spark env: Spark Connector, Exchange, Algorithm..."
	cd $WOKRING_PATH
	if [ ! -d "$WOKRING_PATH/nebula-up" ]; then
		git clone https://github.com/wey-gu/nebula-up.git
	else
		logger_warn "$WOKRING_PATH/nebula-up already exists, existing repo will be reused"
	fi
	cd nebula-up && git stash 1>/dev/null 2>/dev/null && git pull 1>/dev/null 2>/dev/null
	cd spark
	docker-compose pull || logger_error "Failed to pull docker images for spark env"
	docker-compose up -d
	wget -O download/nebula-spark-connector.jar https://repo1.maven.org/maven2/com/vesoft/nebula-spark-connector/$SPARK_C_VERSION/nebula-spark-connector-$SPARK_C_VERSION.jar 1>/dev/null 2>/dev/null || logger_error "Failed to download Nebula Spark Connector Package"
	wget -O download/nebula-exchange.jar https://github.com/vesoft-inc/nebula-exchange/releases/download/v$EXCHANGE_VERSION/nebula-exchange_spark_2.4-$EXCHANGE_VERSION.jar 1>/dev/null 2>/dev/null || logger_error "Failed to download Nebula Exchange Package"
	wget -O download/nebula-algo.jar https://repo1.maven.org/maven2/com/vesoft/nebula-algorithm/$ALGO_VERSION/nebula-algorithm-$ALGO_VERSION.jar 1>/dev/null 2>/dev/null || logger_error "Failed to download Nebula Algorithm Package"
	if [ "$ALGO" == "true" ]; then
		logger_info "Downloading soc-LiveJournal1 dataset..."
		wget -O download/soc-LiveJournal1.txt.gz https://snap.stanford.edu/data/soc-LiveJournal1.txt.gz
		gzip -d download/soc-LiveJournal1.txt.gz
		sed -i '1,4d' download/soc-LiveJournal1.txt
	fi
	sudo bash -c "cat > $WOKRING_PATH/nebula-pyspark.sh" << EOF
#!/usr/bin/env bash
# Copyright (c) 2021 vesoft inc. All rights reserved.
#
# This source code is licensed under Apache 2.0 License,


# Usage: nebula-pyspark.sh

export DOCKER_DEFAULT_PLATFORM=linux/amd64;
sudo docker exec -it spark_master_1 /spark/bin/pyspark --driver-class-path /root/download/nebula-spark-connector.jar --jars /root/download/nebula-spark-connector.jar
EOF
	sudo chmod +x $WOKRING_PATH/nebula-pyspark.sh
	logger_info "Created nebula-pyspark.sh 😁"

	sudo bash -c "cat > $WOKRING_PATH/nebula-exchange-example.sh" << EOF
#!/usr/bin/env bash
# Copyright (c) 2021 vesoft inc. All rights reserved.
#
# This source code is licensed under Apache 2.0 License,


# Usage: nebula-exchange-example.sh

export DOCKER_DEFAULT_PLATFORM=linux/amd64;
sudo docker exec -it spark_master_1 /spark/bin/spark-submit --master local --class com.vesoft.nebula.exchange.Exchange /root/download/nebula-exchange.jar -c /root/exchange.conf
EOF
	sudo chmod +x $WOKRING_PATH/nebula-exchange-example.sh
	logger_info "Created nebula-exchange-example.sh 😁"

	sudo bash -c "cat > $WOKRING_PATH/load-LiveJournal-dataset.sh" << EOF
#!/usr/bin/env bash
# Copyright (c) 2021 vesoft inc. All rights reserved.
#
# This source code is licensed under Apache 2.0 License,


# Usage: load-LiveJournal-dataset.sh

export DOCKER_DEFAULT_PLATFORM=linux/amd64;
sudo docker run --rm -ti \\
    --network=nebula-net \\
    -v $WOKRING_PATH/nebula-up/importer/LiveJournal.yaml:/root/importer.yaml \\
    -v $WOKRING_PATH/nebula-up/spark/download:/root \\
    vesoft/nebula-importer:v3.1.0 \\
    --config /root/importer.yaml

EOF
	sudo chmod +x $WOKRING_PATH/load-LiveJournal-dataset.sh
	logger_info "Created load-LiveJournal-dataset.sh 😁"

	sudo bash -c "cat > $WOKRING_PATH/nebula-algo-pagerank-example.sh" << EOF
#!/usr/bin/env bash
# Copyright (c) 2021 vesoft inc. All rights reserved.
#
# This source code is licensed under Apache 2.0 License,


# Usage: nebula-algo-pagerank-example.sh

export DOCKER_DEFAULT_PLATFORM=linux/amd64;
sudo docker exec -it spark_master_1 /spark/bin/spark-submit --master "local" --conf spark.rpc.askTimeout=6000s \\
    --class com.vesoft.nebula.algorithm.Main \\
    --driver-memory 4g /root/download/nebula-algo.jar \\
    -p /root/pagerank.conf
EOF
	sudo chmod +x $WOKRING_PATH/nebula-algo-pagerank-example.sh
	logger_info "Created nebula-algo-pagerank-example.sh 😁"
}

function install_nebula_graph_br {
	# if BR is not true, then skip, else continue to install.
	if [ "$BR" != "true" ]; then
		logger_info "Skip BR env installation in current mode: $MODE"
		return
	fi
	# if BR is true, then continue to install.
	logger_info "Installing Nebula BR env: MINIO, Nebula Agents, BR"
	cd $WOKRING_PATH
	if [ ! -d "$WOKRING_PATH/nebula-up" ]; then
		git clone https://github.com/wey-gu/nebula-up.git
	else
		logger_warn "$WOKRING_PATH/nebula-up already exists, existing repo will be reused"
	fi
	cd nebula-up && git stash 1>/dev/null 2>/dev/null && git pull 1>/dev/null 2>/dev/null
	cd backup_restore
	docker-compose pull || logger_error "Failed to pull docker images for backup_restore env"
	docker-compose up -d

	sudo bash -c "cat > $WOKRING_PATH/nebula-br.sh" << EOF
#!/usr/bin/env bash
# Copyright (c) 2021 vesoft inc. All rights reserved.
#
# This source code is licensed under Apache 2.0 License,


# Usage: nebula-br.sh --help or nebula-br.sh show --help

export DOCKER_DEFAULT_PLATFORM=linux/amd64;
sudo docker exec -it backup_restore_graphd1-agent_1 br "\$@"
EOF
	sudo chmod +x $WOKRING_PATH/nebula-br.sh
	logger_info "Created nebula-br.sh 😁"


	sudo bash -c "cat > $WOKRING_PATH/nebula-br-backup-full.sh" << EOF
#!/usr/bin/env bash
# Copyright (c) 2021 vesoft inc. All rights reserved.
#
# This source code is licensed under Apache 2.0 License,


# Usage: nebula-br-backup-full.sh

export DOCKER_DEFAULT_PLATFORM=linux/amd64;
sudo docker exec -it backup_restore_graphd1-agent_1 br backup full --meta "metad0:9559" --s3.endpoint "http://nginx:9000" --storage="s3://nebula-br-bucket/" --s3.access_key=minioadmin --s3.secret_key=minioadmin --s3.region=default
EOF
	sudo chmod +x $WOKRING_PATH/nebula-br-backup-full.sh
	logger_info "Created nebula-br-backup-full.sh 😁"


	sudo bash -c "cat > $WOKRING_PATH/nebula-br-show.sh" << EOF
#!/usr/bin/env bash
# Copyright (c) 2021 vesoft inc. All rights reserved.
#
# This source code is licensed under Apache 2.0 License,


# Usage: nebula-br-show.sh

export DOCKER_DEFAULT_PLATFORM=linux/amd64;
sudo docker exec -it backup_restore_graphd1-agent_1 br show --s3.endpoint "http://nginx:9000" --storage="s3://nebula-br-bucket/" --s3.access_key=minioadmin --s3.secret_key=minioadmin --s3.region=default
EOF
	sudo chmod +x $WOKRING_PATH/nebula-br-show.sh
	logger_info "Created nebula-br-show.sh 😁"

	sudo bash -c "cat > $WOKRING_PATH/nebula-br-restore-full.sh" << EOF
#!/usr/bin/env bash
# Copyright (c) 2021 vesoft inc. All rights reserved.
#
# This source code is licensed under Apache 2.0 License,


# Usage: nebula-br-restore-full.sh

export DOCKER_DEFAULT_PLATFORM=linux/amd64;
sudo docker exec -it backup_restore_graphd1-agent_1 br restore full --meta "metad0:9559" --s3.endpoint "http://nginx:9000" --storage="s3://nebula-br-bucket/" --s3.access_key=minioadmin --s3.secret_key=minioadmin --s3.region=default --name "\$@"
EOF
	sudo chmod +x $WOKRING_PATH/nebula-br-restore-full.sh
	logger_info "Created nebula-br-restore-full.sh 😁"

}



function print_footer {

	echo "┌────────────────────────────────────────┐"
	echo "│ 🌌 Nebula-Graph Playground is Up now!  │"
	echo "├────────────────────────────────────────┤"
	echo "│                                        │"
	echo "│ 🎉 Congrats! Your Nebula is Up now!    │"
	echo "│    $ cd ~/.nebula-up                   │"
	echo "│                                        │"
	echo "│ 🌏 Visit Studio From Web Browser:      │"
	echo "│      http://127.0.0.1:7001             │"
	echo "│      http://<other_interface>:7001     │"
	echo "│                                        │"
	echo "│ ⚙ Visit Dashboard From Web Browser:    │"
	echo "│      http://127.0.0.1:7003             │"
	echo "│      http://<other_interface>:7003     │"
	echo "│                                        │"
	echo "│ 🔥 Or access via Nebula Console:       │"
	echo "│    $ ~/.nebula-up/console.sh           │"
	echo "│    To remove the playground:           │"
	echo "│    $ ~/.nebula-up/uninstall.sh         │"
	echo "│                                        │"
	echo "│ 🚀 Have Fun!                           │"
	echo "│                                        │"
	echo "└────────────────────────────────────────┘"

}

function print_footer_error {

	echo "┌────────────────────────────────────────┐"
	echo "│ 🌌 Nebula-Up run into issues 😢        │"
	echo "├────────────────────────────────────────┤"
	echo "│                                        │"
	echo "│ 🎉 To cleanup:                         │"
	echo "│    $ ~/.nebula-up/uninstall.sh         │"
	echo "│                                        │"
	echo "└────────────────────────────────────────┘"

}

function main {
	print_banner
	case $NEBULA_VERSION in
	v3.1 | 3.1 | 3.1.0 | v3 )
		NEBULA_VERSION="v3.1.0"
		STUDIO_VERSION="3.2.3"
		CONSOLE_VERSION="v3.0.0"
		EXCHANGE_VERSION="3.0.0"
		ALGO_VERSION="3.0.0"
		SPARK_C_VERSION="3.0.0"
		;;

	*)
		logger_info "VERSION not provided"
		NEBULA_VERSION="v3.1.0"
		STUDIO_VERSION="3.2.3"
		CONSOLE_VERSION="v3.0.0"
		EXCHANGE_VERSION="3.0.0"
		ALGO_VERSION="3.0.0"
		SPARK_C_VERSION="3.0.0"
		;;
	esac
	logger_info "Installing Nebula Graph $NEBULA_VERSION"

	case $MODE in
	all )
		DASHBOARD="true"
		SPARK="true"
		BR="true"
		ALGO="true"
		;;
	spark )
		DASHBOARD="false"
		SPARK="true"
		ALGO="true"
		BR="false"
		;;
	algo )
		DASHBOARD="false"
		SPARK="true"
		ALGO="true"
		BR="false"
		;;
	dashboard )
		DASHBOARD="true"
		SPARK="false"
		ALGO="false"
		BR="false"
		;;
	br )
		DASHBOARD="false"
		SPARK="false"
		ALGO="false"
		BR="true"
		;;
	*)
		logger_info "Mode not provided, default to all-in-one"
		DASHBOARD="true"
		SPARK="true"
		ALGO="true"
		BR="true"
		;;
	esac

	CURRENT_PATH="$pwd"
	WOKRING_PATH="$HOME/.nebula-up"
	mkdir -p $WOKRING_PATH && cd $WOKRING_PATH
	PLATFORM=$(get_platform)
	CN_NETWORK=false
	if is_CN_NETWORK; then
		CN_NETWORK=true
	fi

	excute_step verify_sudo_permission
	logger_info "Preparing Nebula-Up Uninstall Script..."
	excute_step create_uninstall_script

	logger_info "Ensuring Depedencies..."
	excute_step ensure_dependencies

	logger_info "Boostraping Nebula Graph Cluster with Docker Compose..."
	excute_step install_nebula_graph

	logger_info "Boostraping Nebula Graph Studio with Docker Compose..."
	excute_step install_nebula_graph_studio

	logger_info "Preparing Nebula Graph Console Script..."
	excute_step install_nebula_graph_console

	logger_info "Installing Nebula Graph Dashboard..."
	excute_step install_nebula_graph_dashboard

	logger_info "Installing Nebula Graph Spark Connector, Exchange & Algorithm..."
	excute_step install_nebula_graph_spark

	logger_info "Installing Nebula Graph Backup and Restore..."
	excute_step install_nebula_graph_br

	excute_step waiting_for_nebula_graph_up

	print_footer
}

NEBULA_VERSION=$1
MODE=$2
main
