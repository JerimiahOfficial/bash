#!/bin/bash

curl -O https://rpmfind.net/linux/dag/redhat/el7/en/x86_64/dag/RPMS/sshpass-1.05-1.el7.rf.x86_64.rpm
curl -O https://raw.githubusercontent.com/JerimiahOfficial/bash/main/nfs%20lab/host_info_nfs.sh

# Intall sshpass and nfs-utils on w01
echo "userpass" | sudo -S -k yum install sshpass-1.05-1.el7.rf.x86_64.rpm -y -q
echo "userpass" | sudo -S -k yum install nfs-utils -y -q

# scp host_info_nfs.sh to s01
sshpass -p "adminpass" scp -o StrictHostKeyChecking=no ~/Downloads/host_info_nfs.sh root@s01:/tmp

# ssh into root on s01
sshpass -p "adminpass" ssh root@s01 -o StrictHostKeyChecking=no /bin/sh <<-EOF
	yum install nfs-utils -y -q

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

# ssh to root on w01 and run a few commands
sshpass -p "adminpass" ssh root@w01 -o StrictHostKeyChecking=no /bin/sh <<-EOF
	# Create the users margaret and katherine on w01
	useradd -u 2000 margaret
	useradd -u 2001 katherine

	# Change the passwd for both new users to 123
	echo "123" | passwd --stdin margaret
	echo "123" | passwd --stdin katherine

	# Create research group and add margaret and katherine to it on w01
	groupadd research
	usermod -a -G research margaret
	usermod -a -G research katherine

	# Create the shared directories on w01
	mkdir -p /nfs_shares/scratch
	mkdir -p /nfs_shares/research
	mkdir -p /nfs_shares/pub

	# Create fstab entries
	echo "s01:/nfs_shares/scratch /nfs_shares/scratch nfs defaults 0 0" >> /etc/fstab
	echo "s01:/nfs_shares/research /nfs_shares/research nfs defaults 0 0" >> /etc/fstab
	echo "s01:/nfs_shares/pub /nfs_shares/pub nfs defaults 0 0" >> /etc/fstab

	# Mount the shared directories
	mount -t nfs s01:/nfs_shares/scratch /nfs_shares/scratch
	mount -t nfs s01:/nfs_shares/research /nfs_shares/research
	mount -t nfs s01:/nfs_shares/pub /nfs_shares/pub

	# Create test files in the shared directories
	echo "Test" > /nfs_shares/scratch/root_test.txt
	# Test file should not be able to be created in the research directory
	echo "Test" > /nfs_shares/research/root_test.txt
	echo "Test" > /nfs_shares/pub/root_test.txt
EOF

# ssh to margaret on w01 and run a few commands
sshpass -p "123" ssh margaret@w01 -o StrictHostKeyChecking=no  /bin/sh <<-EOF
	# Create test files in the shared directories
	echo "Test" > /nfs_shares/scratch/margaret_test.txt
	echo "Test" > /nfs_shares/research/margaret_test.txt
	echo "Test" > /nfs_shares/pub/margaret_test.txt
EOF

# ssh to katherine on w01 and run a few commands
sshpass -p "123" ssh katherine@w01 -o StrictHostKeyChecking=no /bin/sh <<-EOF
	# Create test files in the shared directories
	echo "Test" > /nfs_shares/scratch/katherine_test.txt
	echo "Test" > /nfs_shares/research/katherine_test.txt
	echo "Test" > /nfs_shares/pub/katherine_test.txt
EOF

# # Chmod the directories
# echo "adminpass" | su -c "chmod 777 /nfs_shares/scratch" root
# echo "adminpass" | su -c "chmod 777 /nfs_shares/research" root
# echo "adminpass" | su -c "chmod 777 /nfs_shares/pub" root

# excute the script on s01
sshpass -p "adminpass" ssh root@s01 -o StrictHostKeyChecking=no /bin/sh <<-EOF
	# install net-tools
	yum install net-tools -y -q

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
