#!/bin/bash

initialize_master() {
  # If admin.conf exists, assume cluster already initialized
  if [[ -f /etc/kubernetes/admin.conf ]]; then
    echo "Kubernetes control plane already initialized on this host."
    echo "Skipping kubeadm init."
  else
    kubeadm init --pod-network-cidr="$POD_CIDR"
  fi

  # copy kubeconfig for current user (root or sudo caller)
  TARGET_HOME=${SUDO_USER:+/home/$SUDO_USER:$SUDO_USER}
  # if script run as sudo, set up for the invoking user; otherwise root.
  if [[ -n "${SUDO_USER:-}" ]]; then
    mkdir -p /home/"${SUDO_USER}"/.kube
    cp -i /etc/kubernetes/admin.conf /home/"${SUDO_USER}"/.kube/config
    chown "${SUDO_UID:-0}":"${SUDO_GID:-0}" /home/"${SUDO_USER}"/.kube/config
    echo "kubectl config copied to /home/${SUDO_USER}/.kube/config"
  else
    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config
    echo "kubectl config copied to $HOME/.kube/config"
  fi

  # ensure kubectl in PATH for immediate usage
  export KUBECONFIG=/etc/kubernetes/admin.conf
}

apply_cni_and_output_join() {
  kubectl apply -f "$CALICO_MANIFEST"

  # Create (or refresh) a reusable join command (auto-creates token if needed)
  echo "#!/bin/bash" > "$JOIN_OUTPUT"
  kubeadm token create --print-join-command >> "$JOIN_OUTPUT"
  chmod +x "$JOIN_OUTPUT"
  echo "Join command saved to: $JOIN_OUTPUT"
  echo "Print the join command:"
  cat "$JOIN_OUTPUT"
}


