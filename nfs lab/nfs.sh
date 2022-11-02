#!/bin/bash

curl -O https://rpmfind.net/linux/dag/redhat/el7/en/x86_64/dag/RPMS/sshpass-1.05-1.el7.rf.x86_64.rpm
curl -O https://raw.githubusercontent.com/JerimiahOfficial/bash/main/nfs%20lab/host_info_nfs.sh

echo "adminpass" | su -c "yum install sshpass*.rpm -y -q"
echo "adminpass" | su -c "yum install nfs-utils -y -q"

sshpass -p "adminpass" ssh root@s01 /bin/sh <<-EOF
    yum install nfs-utils -y -q
    yum install net-tools -y -q

    firewall-cmd --permanent --add-service=nfs3
    firewall-cmd --reload

    systemctl enable --now nfs-server

    useradd -u 2000 margaret
    useradd -u 2001 katherine

    groupadd research
    usermod -a -G research margaret
    usermod -a -G research katherine

    mkdir -p /nfs_shares/scratch
    mkdir -p /nfs_shares/research
    mkdir -p /nfs_shares/pub

    echo "/nfs_shares/scratch w01(rw)" >>/etc/exports
    echo "/nfs_shares/research w01(rw,no_root_squash,all_squash,anongid=2002)" >>/etc/exports
    echo "/nfs_shares/pub w01(rw)" >>/etc/exports

    chmod 777 /nfs_shares/scratch

    chgrp research /nfs_shares/research
    chmod 1770 /nfs_shares/research
    
    chmod 777 /nfs_shares/pub

    usermod -l w01_guest nobody
    groupmod -n w01_guest nobody

    exportfs -r
EOF

# Create the users margaret and katherine on w01
echo "adminpass" | su -c "useradd -u 2000 margaret" root
echo "adminpass" | su -c "useradd -u 2001 katherine" root
echo "adminpass" | su -c "echo "123" | passwd --stdin margaret" root
echo "adminpass" | su -c "echo "123" | passwd --stdin katherine" root

# Create research group and add margaret and katherine to it on w01
echo "adminpass" | su -c "groupadd research" root
echo "adminpass" | su -c "usermod -a -G research margaret" root
echo "adminpass" | su -c "usermod -a -G research katherine" root

# Create the shared directories
echo "adminpass" | su -c "mkdir -p /nfs_shares/scratch" root
echo "adminpass" | su -c "mkdir -p /nfs_shares/research" root
echo "adminpass" | su -c "mkdir -p /nfs_shares/pub" root

# Create fstab entries
echo "adminpass" | su -c "echo \"s01:/nfs_shares/scratch /nfs_shares/scratch nfs defaults 0 0\" >> /etc/fstab" root
echo "adminpass" | su -c "echo \"s01:/nfs_shares/research /nfs_shares/research nfs defaults 0 0\" >> /etc/fstab" root
echo "adminpass" | su -c "echo \"s01:/nfs_shares/pub /nfs_shares/pub nfs defaults 0 0\" >> /etc/fstab" root

# Mount the shared directories
echo "adminpass" | su -c "mount -t nfs s01:/nfs_shares/scratch /nfs_shares/scratch" root
echo "adminpass" | su -c "mount -t nfs s01:/nfs_shares/research /nfs_shares/research" root
echo "adminpass" | su -c "mount -t nfs s01:/nfs_shares/pub /nfs_shares/pub" root

# Chmod the directories
echo "adminpass" | su -c "chmod 777 /nfs_shares/scratch" root
echo "adminpass" | su -c "chmod 777 /nfs_shares/research" root
echo "adminpass" | su -c "chmod 777 /nfs_shares/pub" root

# try to create a file in /nfs_shares/scratch
echo "adminpass" | su -c "echo \"test\" > /nfs_shares/scratch/root" root
echo "123" | su -c "echo \"test\" >> /nfs_shares/scratch/margaret" margaret
echo "123" | su -c "echo \"test\" >> /nfs_shares/scratch/katherine" katherine

# try to create a file in /nfs_shares/research
echo "root is expected to fail"
echo "adminpass" | su -c "echo \"test\" > /nfs_shares/research/root" root
echo "123" | su -c "echo \"test\" >> /nfs_shares/research/margaret" margaret
echo "123" | su -c "echo \"test\" >> /nfs_shares/research/katherine" katherine

# try to create a file in /nfs_shares/pub
echo "adminpass" | su -c "echo \"test\" > /nfs_shares/pub/root" root
echo "123" | su -c "echo \"test\" >> /nfs_shares/pub/margaret" margaret
echo "123" | su -c "echo \"test\" >> /nfs_shares/pub/katherine" katherine

# Upload the script to the s01
sshpass -p "adminpass" scp -o StrictHostKeyChecking=no ~/Downloads/host_info_nfs.sh root@s01:/tmp

# excute the script on s01
sshpass -p "adminpass" ssh root@s01 /bin/sh <<-EOF
    # cd /tmp
    cd /tmp

    # chmod +x the script
    chmod +x host_info_nfs.sh

    # execute the script
    ./host_info_nfs.sh
EOF

# scp the results to the local machine
sshpass -p "adminpass" scp root@s01:/tmp/s01_report_nfs.html /tmp

# open the results
firefox /tmp/s01_report_nfs.html

# exit the script
exit 0
