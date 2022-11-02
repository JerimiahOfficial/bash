#!/bin/bash -e

curl -O https://rpmfind.net/linux/dag/redhat/el7/en/x86_64/dag/RPMS/sshpass-1.05-1.el7.rf.x86_64.rpm
curl -O https://raw.githubusercontent.com/JerimiahOfficial/bash/main/nfs%20lab/host_info_nfs.sh

echo "userpass" | sudo -S -k yum install sshpass*.rpm -y -q

sshpass -p "adminpass" scp -o StrictHostKeyChecking=no ~/Downloads/host_info_nfs.sh root@s01:/tmp
sshpass -p "adminpass" ssh root@s01 /bin/sh << EOF

yum install -y nfs-utils
yum install -y net-tools

firewall-cmd --permanent --add-service=nfs3
firewall-cmd --reload

systemctl enable --now nfs-server

useradd -u 2000 margaret
useradd -u 2001 katherine

groupadd research
usermod -a -G research margaret
usermod -a -G research katherine

mkdir -p /nfs_shares/scratch
echo "/nfs_shares/scratch w01(rw,sync,no_root_squash)" >> /etc/exports

mkdir -p /nfs_shares/research
chgrp research /nfs_shares/research
chmod 2770 /nfs_shares/research
echo "/nfs_shares/research w01(rw,sync,no_root_squash,all_squash,anongid=2002)" >> /etc/exports

mkdir -p /nfs_shares/pub
echo "/nfs_shares/pub w01(rw,sync,root_squash,)" >> /etc/exports

usermod -l w01_guest nobody
groupmod -n w01_guest nobody

exportfs -r
EOF

echo "userpass" | sudo -S -k yum install nfs-utils -y -q

echo "userpass" | sudo -S -k useradd -u 2000 margaret
echo "userpass" | sudo -S -k useradd -u 2001 katherine

echo "userpass" | sudo -S -k echo "123" | passwd --stdin margaret
echo "userpass" | sudo -S -k echo "123" | passwd --stdin katherine

echo "userpass" | sudo -S -k groupadd research
echo "userpass" | sudo -S -k usermod -a -G research margaret
echo "userpass" | sudo -S -k usermod -a -G research katherine

# Adding the share to /etc/fstab and mounting it
echo "userpass" | sudo echo "s01:/nfs_shares/scratch /nfs_shares/scratch nfs defaults 0 0" >> /etc/fstab
echo "userpass" | sudo mount -t nfs s01:/nfs_shares/scratch /nfs_shares/scratch

# try to create a file in /nfs_shares/scratch
echo "adminpass" | su root -c "echo \"test\" > /nfs_shares/scratch/test.txt"
echo "123" | su margaret -c "echo \"test\" > /nfs_shares/scratch/test.txt"
echo "123" | su katherine -c "echo \"test\" > /nfs_shares/scratch/test.txt"

# Adding the share to /etc/fstab and mounting it
echo "userpass" | sudo echo "s01:/nfs_shares/research /nfs_shares/research nfs defaults 0 0" >> /etc/fstab
echo "userpass" | sudo mount -t nfs s01:/nfs_shares/research /nfs_shares/research

# try to create a file in /nfs_shares/research
echo "adminpass" | su root -c "echo \"test\" > /nfs_shares/research/test.txt"
echo "123" | su margaret -c "echo \"test\" > /nfs_shares/research/test.txt"
echo "123" | su katherine -c "echo \"test\" > /nfs_shares/research/test.txt"

# Adding the share to /etc/fstab and mounting it
echo "userpass" | sudo echo "s01:/nfs_shares/pub /nfs_shares/pub nfs defaults 0 0" >> /etc/fstab
echo "userpass" | sudo mount -t nfs s01:/nfs_shares/pub /nfs_shares/pub

# try to create a file in /nfs_shares/pub
echo "adminpass" | su root -c "echo \"test\" > /nfs_shares/pub/test.txt"
echo "123" | su margaret -c "echo \"test\" > /nfs_shares/pub/test.txt"
echo "123" | su katherine -c "echo \"test\" > /nfs_shares/pub/test.txt"