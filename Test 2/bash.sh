#!/bin/bash -e

# download dependencies
echo "Downloading dependencies"
curl -O https://rpmfind.net/linux/dag/redhat/el7/en/x86_64/dag/RPMS/sshpass-1.05-1.el7.rf.x86_64.rpm

# install dependencies
echo "Installing dependencies"
yum install sshpass-1.05-1.el7.rf.x86_64.rpm -y -q

while [ ! -f /usr/bin/sshpass ]; do
    sleep 1
done

# notify the user that dependencies are installed
echo "Dependencies installed"

# Part B: Backup (2 points)
# Create a tar archive named /tmp/etc.tar on s01 containing all files from the local /etc directory tree.
tar -cvf /tmp/etc.tar /etc

# Part C: NFS (5 points)
# The shared directory must be called /nfs/w01
# Any user on w01 must appear as the user named alice when accessing the share
# Any user on w01 must appear to belong to the group named w01users when accessing the share
# All configuration changes must survive a reboot
# The share must be mounted by w01 when you run the grading script
# The share must contain at least one test file created by a user from w01
groupadd w01users

useradd alice
usermod -aG w01users alice

uid=$(id -u alice)
gid=$(id -g w01users)

yum install nfs-utils -y -q

firewall-cmd --permanent --add-service=nfs3
firewall-cmd --reload

mkdir -p /nfs/w01

echo "/nfs/w01 *(rw,sync,no_root_squash,no_all_squash,anonuid=$uid,anongid=$gid)" >>/etc/exports

systemctl enable --now nfs-server

# w01
mkdir -p /nfs/w01

echo "s01:/nfs/w01 /nfs/w01 nfs defaults 0 2" >>/etc/fstab

mount -t nfs s01:/nfs/w01 /nfs/w01

echo "test" >/nfs/w01/test.txt

# Part D: Logging (5 points)
# Install the Apache web server on w01. Configure httpd to log it's errors via rsyslog to the file /var/log/httpd.err on s01
# All changes must be permanent (survive reboot)
# You must cause the web server to generate some errors to test your work
yum install httpd -y

echo "ErrorLog syslog:local2" >>/etc/httpd/conf/httpd.conf

systemctl start httpd

curl http://localhost

echo "local2.* /var/log/httpd_err" >>/etc/rsyslog.conf

systemctl restart rsyslog

curl http://localhost

# Part E: Incremental Backup (2 points)
# You made some changes to the contents of the /etc directory tree on s01 since the backup was created in section B. Create a tar archive named /tmp/changes.tar containing only the files that have changed since the tar backup from section B completed.
tar -cvf /tmp/changes.tar -N /tmp/etc.tar /etc

# Run the grading script
