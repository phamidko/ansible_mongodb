#!/bin/bash

## !IMPORTANT ##
#
## This script is tested only in the generic/ubuntu2004 Vagrant box
## If you use a different version of Ubuntu or a different Ubuntu Vagrant box test this again
#

echo "[TASK 1] Disable and turn off SWAP"
sed -i '/swap/d' /etc/fstab
swapoff -a

echo "[TASK 2] Stop and Disable firewall"
systemctl disable --now ufw >/dev/null 2>&1

echo "[TASK 3] Enable and Load Kernel modules"
cat >>/etc/modules-load.d/containerd.conf<<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

echo "[TASK 4] Add Kernel settings"
cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system >/dev/null 2>&1

echo "[TASK 5] Install pymongo 3.6"
apt update -qq >/dev/null 2>&1

add-apt-repository ppa:deadsnakes/ppa
apt-get install -y build-essential libssl-dev libffi-dev python-dev software-properties-common
update-alternatives --install /usr/bin/python python /usr/bin/python3.6 1
apt install -y python3-pip python3.6-distutils # python-pymongo 
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python get-pip.py 
python -m pip install ansible
python3 -m pip install 'pymongo[srv]' #compatiable with python 3.6 https://docs.mongodb.com/drivers/pymongo/
python3 -m pip install 'pymongo[tls]'
python3 -m pip install 'pymongo[aws]'
python3 -m pip install requests


echo "[TASK 6] Add apt repo for mongodb"
#apt-get install gnupg -y
wget -qO - https://www.mongodb.org/static/pgp/server-3.6.asc | sudo apt-key add --yes - >/dev/null 2>&1
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/3.6 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.6.list


echo "[TASK 7] Install Mongo components and configuration"
apt-get update
apt-get install -y mongodb-org

mkdir -p /mongodb/data
setfacl -R -m u:mongodb:rwx /mongodb/data
sed -i -e '/dbPath/ s/: .*/: \/mongodb\/data /' /etc/mongod.conf
echo "storage.directoryPerDB: true" >> /etc/mongod.conf

# sed -i '/#security/csecurity:\n  authorization: "enabled"\n' /etc/mongod.conf
sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mongod.conf

# allways make replicaset 
# sed -i '/#replication/creplication:\n  replSetName: rs0\n' /etc/mongod.conf


systemctl start mongod 
systemctl enable mongod >/dev/null 2>&1


#mongod --port 27017 --dbpath /mongos/db1 --replSet rs0

echo "[TASK 8] Enable ssh password authentication"
sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
systemctl reload sshd

echo "[TASK 9] Set root password"
echo -e "kubeadmin\nkubeadmin" | passwd root >/dev/null 2>&1
echo "export TERM=xterm" >> /etc/bash.bashrc

echo "[TASK 10] Update /etc/hosts file"
cat >>/etc/hosts<<EOF
172.16.16.100   kmaster.example.com     kmaster
172.16.16.101   kworker1.example.com    kworker1
172.16.16.102   kworker2.example.com    kworker2
EOF