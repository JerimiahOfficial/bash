#!/bin/bash -e

# Part B: Backup (2 points)
# Create a tar archive named /tmp/etc.tar on s01 containing all files from the local /etc directory tree.
tar -cvf /tmp/etc.tar /etc

# Part C: NFS (5 points)
# The shared directory must be called /nfs/w01
# Any user on w01 must appear as the user named alice when accessing the share
# All configuration changes must survive a reboot
# The share must be mounted by w01 when you run the grading script
# The share must contain at least one test file created by a user from w01
mkdir -p /nfs/w01

echo "/nfs/w01 *(rw,sync,no_root_squash)" >>/etc/exports

systemctl restart nfs-server

while [ "$(systemctl is-active nfs-server)" != "active" ]; do
    sleep 1
done

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
