#!/bin/bash

set -e

echo "[1/12] Updating package lists..."
apt update -y

echo "[2/12] Installing prerequisites..."
apt install -y curl wget git make apt-transport-https ca-certificates gnupg lsb-release conntrack socat unzip python3-pip

echo "[3/12] Installing Go (golang)..."
GO_VERSION="1.22.3"
cd /tmp
wget https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
rm -rf /usr/local/go
tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
echo "export PATH=\$PATH:/usr/local/go/bin" >> /etc/profile
export PATH=$PATH:/usr/local/go/bin
go version

echo "[4/12] Installing Docker..."
apt install -y docker.io
systemctl enable docker
systemctl start docker

echo "[5/12] Adding current user to docker group (optional)..."
usermod -aG docker $USER

echo "[6/12] Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

echo "[7/12] Installing Minikube..."
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
install -o root -g root -m 0755 minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64

echo "[8/12] Installing crictl..."
CRICTL_VERSION="v1.29.0"
curl -LO https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz
tar zxvf crictl-${CRICTL_VERSION}-linux-amd64.tar.gz -C /usr/local/bin
rm -f crictl-${CRICTL_VERSION}-linux-amd64.tar.gz

echo "[9/12] Installing cri-dockerd..."
cd /tmp
git clone https://github.com/Mirantis/cri-dockerd.git
cd cri-dockerd
mkdir -p bin
go build -o bin/cri-dockerd
install -o root -g root -m 0755 bin/cri-dockerd /usr/local/bin/cri-dockerd

# Install systemd service
cp -a packaging/systemd/* /etc/systemd/system
sed -i 's:/usr/bin/cri-dockerd:/usr/local/bin/cri-dockerd:' /etc/systemd/system/cri-docker.service
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable cri-docker.service
systemctl enable --now cri-docker.socket

cd /tmp
rm -rf cri-dockerd

echo "[10/12] Installing CNI plugins..."
CNI_VERSION="1.3.0"
mkdir -p /opt/cni/bin
cd /opt/cni/bin
curl -LO https://github.com/containernetworking/plugins/releases/download/v${CNI_VERSION}/cni-plugins-linux-amd64-v${CNI_VERSION}.tgz
tar -xzvf cni-plugins-linux-amd64-v${CNI_VERSION}.tgz
rm cni-plugins-linux-amd64-v${CNI_VERSION}.tgz

echo "[11/12] Installing AWS CLI v2..."
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip
aws --version

echo "[12/12] Starting Minikube with --driver=none..."
export CHANGE_MINIKUBE_NONE_USER=true
minikube start --driver=none

echo "✅ Minikube with all components (cri-dockerd, crictl, CNI, AWS CLI) is installed and running!"
