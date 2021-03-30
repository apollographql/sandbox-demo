#! /bin/bash

subgraphs_yaml='./subgraphs.yml'
csdl_file="./supergraph.csdl"
rover_version='v0.0.4'

# Following two functions are Copyright (c) 2018 Intel Corporation
# found at https://raw.githubusercontent.com/kata-containers/runtime/master/.ci/install-yq.sh
#
# SPDX-License-Identifier: Apache-2.0
#

# If we fail for any reason a message will be displayed
die() {
	msg="$*"
	echo "ERROR: $msg" >&2
	exit 1
}

# Install the yq yaml query package from the mikefarah github repo
# Install via binary download, as we may not have golang installed at this point
function install_yq() {
	local yq_path="/usr/local/bin/yq"
	local yq_pkg="github.com/mikefarah/yq"


	read -r -a sysInfo <<< "$(uname -sm)"

	case "${sysInfo[0]}" in
	"Linux" | "Darwin")
		goos=$(echo "${sysInfo[0],}" | tr '[:upper:]' '[:lower:]')
		;;
	"*")
		die "OS ${sysInfo[0]} not supported"
		;;
	esac

	case "${sysInfo[1]}" in
	"aarch64")
		goarch=arm64
		;;
	"ppc64le")
		goarch=ppc64le
		;;
	"x86_64")
		goarch=amd64
		;;
	"s390x")
		goarch=s390x
		;;
	"*")
		die "Arch ${sysInfo[1]} not supported"
		;;
	esac


	# Check curl
	if ! command -v "curl" >/dev/null; then
		die "Please install curl"
	fi

	local yq_version='v4.6.3'
	local yq_binary_name="yq_${goos}_${goarch}"

	local yq_url="https://${yq_pkg}/releases/download/${yq_version}/${yq_binary_name}.tar.gz"
	echo Attempting to install to ${yq_path} from ${yq_url} 
	curl -sSLf ${yq_url} | tar xz && mv ${yq_binary_name} ${yq_path}
	[ $? -ne 0 ] && die "Download ${yq_url} failed"
	chmod +x ${yq_path}
	if ! command -v "${yq_path}" >/dev/null; then
		die "Cannot not get ${yq_path} executable"
	fi
	echo $(yq --version)
}

install_rover=true

if command -v rover >/dev/null 2>&1; then
	if [[ "v$(rover --version | awk '{print $NF}')" == "${rover_version}" ]]; then
		echo "Rover was already installed at ${rover_version}, so skipping install"
		install_rover=false
	else
		echo "Rover is installed, but at an older version ($(rover --version)) than this script expects."
	fi
fi

if ${install_rover}; then
	read -p "Rover ${rover_version} is not yet installed, do you want to install it now? [type y to accept] " -n 1 -r
	echo    # (optional) move to a new line
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo "Attempt to install rover..."

		curl -sSL https://raw.githubusercontent.com/apollographql/rover/${rover_version}/installers/binstall/scripts/nix/install.sh | sh 

		if [[ ! -z "$BASH_ENV" ]]; then
		  echo 'Found BASH_ENV defined, so writing rover path there - this makes CI work.'
		  echo 'export PATH=$HOME/.rover/bin:$PATH' >> $BASH_ENV
		fi
	else
		echo "Sorry, we need rover to proceed. Bootstrapping is not complete."
	    exit 1
	fi
fi


if ! command -v rover >/dev/null 2>&1 ; then
    echo "rover appears to not have been installed and available in this shell, so this script cannot continue."
    exit 1
fi

echo "---------- CHECK FOR WHO ROVER IS ACTING AS ----------"
rover config whoami

if ! command -v yq >/dev/null 2>&1; then
	echo "---------- CHECK FOR yq ----------"
	read -p "This script will attempt to install yq, a library for dealing with YAML, is that OK? [type y to accept] " -n 1 -r
	echo    # (optional) move to a new line
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
	    echo "installing yq"
	    install_yq
	else
	    echo "Sorry, we need yq to proceed. Rover was installed, but bootstrapping is not complete."
	    exit 1
	fi
fi



while IFS=$'\t' read -r subgraph _; do
	url=$(echo $subgraph | yq e '.routing_url' -)
	file=$(echo $subgraph | yq e '.schema.file' -)
	echo write $url to $file
	rover graph introspect $url > "${file}"
done < <(yq e '.subgraphs[]' "${subgraphs_yaml}")


rover core build --config "${subgraphs_yaml}" > "${csdl_file}"



#rover graph fetch rickmorty@current > rickmorty.graphql
#rover graph fetch countries1@current > countries.graphql








