#!/bin/bash

#On master

#intialize cluster
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

#Then set up your kubectl config:
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

#deploy a CNI plugin (like Calico):
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
