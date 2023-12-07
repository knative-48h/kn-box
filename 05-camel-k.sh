#!/bin/bash

CAMELK_VERSION=2.1.0

NO_COLOR=${NO_COLOR:-""}
if [ -z "$NO_COLOR" ]; then
  header=$'\e[1;33m'
  reset=$'\e[0m'
else
  header=''
  reset=''
fi

header_text() {
  echo "$header$*$reset"
}

# Function to determine OS and appropriate binary
choose_binary() {
  os_type=$(uname -s)
  arch_type=$(uname -m)
  case "$os_type" in
    Linux) os="linux" ;;
    Darwin) os="darwin" ;;
    *) echo "Unsupported OS"; exit 1 ;;
  esac
  case "$arch_type" in
    x86_64) arch="amd64" ;;
    aarch64) arch="arm64" ;;
    arm64) arch="arm64" ;;
    *) echo "Unsupported Arch"; exit 1 ;;
  esac
  echo "camel-k-client-$CAMELK_VERSION-$os-$arch.tar.gz"
}

download_camelk() {
  # Determine which binary to download
  binary=$(choose_binary)
  if [ $? == 1 ]; then
    echo $binary
    exit 1
  fi
  header_text "Downloading $binary"

  temp_dir=$(mktemp -d)
  pushd "$temp_dir"

  # Download the binary
  curl -LO "https://github.com/apache/camel-k/releases/download/v${CAMELK_VERSION}/$binary"

  # Check if the download was successful
  if [ $? -eq 0 ]; then
    # Extract the binary
    tar -xzf "$binary" kamel
 
    # Specific command for macOS to make it runnable
    if [ "$(uname -s)" == "Darwin" ]; then
      xattr -r -d com.apple.quarantine kamel
    fi
    popd
  else
    echo "Download failed"
    popd
    exit 1
  fi

  cp $temp_dir/kamel .
}

kubectl get crd | grep -q services.serving.knative.dev
if [ $? != 0 ]; then
  echo "Please install Knative Serving first with 01-kn-serving.sh"
  exit 1
fi;

kubectl get crd | grep -q brokers.eventing.knative.dev
if [ $? != 0 ]; then
  echo "Please install Knative Eventing first with 02-kn-eventing.sh"
  exit 1
fi;

if [ ! -x ./kamel ]; then
  download_camelk
fi

header_text "Installing Camel-K operator"
kubectl create namespace camel-system >/dev/null 2>&1 
./kamel install --force --global -n camel-system -w -V
