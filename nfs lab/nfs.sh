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
	# Install nfs-utils on s01
	yum install nfs-utils -y -q

	# Opening the firewall
	firewall-cmd --permanent --add-service=nfs3
	firewall-cmd --reload

	# Making sure nfs is enabled
	systemctl enable --now nfs-server

	# Create users margaret and katherine
	useradd -u 2000 margaret
	useradd -u 2001 katherine

	# Create research group and add users
	groupadd research -g 2002
	usermod -a -G research margaret
	usermod -a -G research katherine

	# Create the shared directories on s01
	mkdir -p /nfs_shares/scratch
	mkdir -p /nfs_shares/research
	mkdir -p /nfs_shares/pub

	# Adding share files to /etc/exports
	echo "/nfs_shares/scratch w01(rw,no_root_squash)" >>/etc/exports
	echo "/nfs_shares/research w01(rw,anongid=2002)" >>/etc/exports
	echo "/nfs_shares/pub w01(rw,no_root_squash,all_squash)" >>/etc/exports

	# Anyone can read/write to the scratch directory
	chmod -R 777 /nfs_shares/pub

	# Only members of the research group can access the research directory
	chown -R root:research /nfs_shares/research
	chmod -R 2770 /nfs_shares/research

	# Everyone has full access to the pub directory
	chmod -R 777 /nfs_shares/pub

	# Changing nobody user to w01_guest
	usermod -l w01_guest nobody
	groupmod -n w01_guest nobody

	# Reload nfs
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
	groupadd research -g 2002
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

	# Set the permissions on the shared directories
	chown -R root:research /nfs_shares/research
	chmod -R 777 /nfs_shares/pub
	chmod -R 2770 /nfs_shares/research
	chmod -R 777 /nfs_shares/pub

	# Create test files in the shared directories
	echo "Test" > /nfs_shares/scratch/root
	# Test file should not be able to be created in the research directory
	echo "Test" > /nfs_shares/research/root
	echo "Test" > /nfs_shares/pub/root
EOF

# ssh to margaret on w01 and create test files
sshpass -p "123" ssh margaret@w01 -o StrictHostKeyChecking=no  /bin/sh <<-EOF
	# Create test files in the shared directories
	echo "Test" > /nfs_shares/scratch/margaret
	echo "Test" > /nfs_shares/research/margaret
	echo "Test" > /nfs_shares/pub/margaret
EOF

# ssh to katherine on w01 and create test files
sshpass -p "123" ssh katherine@w01 -o StrictHostKeyChecking=no /bin/sh <<-EOF
	# Create test files in the shared directories
	echo "Test" > /nfs_shares/scratch/katherine
	echo "Test" > /nfs_shares/research/katherine
	echo "Test" > /nfs_shares/pub/katherine
EOF

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
sshpass -p "adminpass" scp -o StrictHostKeyChecking=no root@s01:/tmp/s01_report_nfs.html /tmp

# open the results
nohup firefox /tmp/s01_report_nfs.html &

# exit the script
exit 0
