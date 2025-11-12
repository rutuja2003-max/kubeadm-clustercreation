#!/usr/bin/env bash
set -euo pipefail


require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    err "This script must be run as root (use sudo)."
  fi
}

apt_update_install() {
  apt-get update
  apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release socat conntrack ipset
}

disable_swap() {
  log "Disabling swap..."
  swapoff -a || true
  sed -i.bak '/\bswap\b/ s/^/#/' /etc/fstab || true
}

configure_sysctl() {
  log "Configuring kernel modules and sysctl..."
  cat >/etc/modules-load.d/k8s.conf <<'EOF'
overlay
br_netfilter
EOF
  modprobe overlay || true
  modprobe br_netfilter || true

  cat >/etc/sysctl.d/k8s.conf <<'EOF'
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
  sysctl --system
}

install_containerd() {
  log "Installing containerd..."
  apt_update_install
  apt-get install -y containerd

  mkdir -p /etc/containerd
  containerd config default > /etc/containerd/config.toml
  # enable systemd cgroup driver
  sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml || true

  systemctl restart containerd
  systemctl enable containerd
}

install_kubernetes_tools() {
  log "Installing kubeadm, kubelet, kubectl..."
  # create keyring dir (works with modern k8s apt repo)
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
    | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

  # NOTE: change the repo path above if you want a different kubernetes version channel
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" \
    > /etc/apt/sources.list.d/kubernetes.list

  apt-get update
  if [ -n "$KUBE_VERSION" ]; then
    apt-get install -y "kubelet=${KUBE_VERSION}" "kubeadm=${KUBE_VERSION}" "kubectl=${KUBE_VERSION}"
  else
    apt-get install -y kubelet kubeadm kubectl
  fi

  apt-mark hold kubelet kubeadm kubectl
  systemctl enable kubelet
}

kubeadm_reset_cleanup() {
  log "Resetting any existing kubeadm state (if present)..."
  kubeadm reset -f || true
  systemctl stop kubelet || true
  rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd /var/lib/cni /etc/cni/net.d || true
}
