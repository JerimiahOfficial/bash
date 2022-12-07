#!/bin/bash

# array of links to download
declare -a links=(
    "https://raw.githubusercontent.com/JerimiahOfficial/bash/main/Utilities/fresh_check.sh"
    "https://raw.githubusercontent.com/JerimiahOfficial/bash/main/Test%202/host_info_t2.sh"
    "https://rpmfind.net/linux/dag/redhat/el7/en/x86_64/dag/RPMS/sshpass-1.05-1.el7.rf.x86_64.rpm"
)

# make sure the script is running as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

# download dependencies to /tmp
echo "Downloading dependencies"
for link in "${links[@]}"; do
    curl -O $link
done

# install dependencies
echo "Installing dependencies"
yum install sshpass-1.05-1.el7.rf.x86_64.rpm -y -q

# copy fresh_check.sh and host_info_t2.sh to s01
echo "Copying scripts to s01"

chmod +x ./fresh_check.sh
chmod +x ./host_info_t2.sh

sshpass -p "adminpass" scp -o StrictHostKeyChecking=no -q ~/Downloads/{fresh_check.sh,host_info_t2.sh} root@s01:/tmp/

echo "Scripts copied to s01"

# Running scripts on s01
echo "Running scripts on s01"
sshpass -p "adminpass" ssh root@s01 -o StrictHostKeyChecking=no /bin/sh <<-EOF
    # Change directories to /tmp
    cd /tmp

    # Run fresh_check.sh
    ./fresh_check.sh

    # Create tar of /etc
    tar -cvf ./etc.tar /etc

    # Create group and user for the NFS server
    groupadd w01users
    useradd alice

    # Store the uid and gid of the create group and user
    uid=\$(id -u alice)
    gid=\$(id -g w01users)

    # Install NFS server
    yum install nfs-utils -y -q

    # Configure the firewall
    firewall-cmd --permanent --add-service=nfs3
    firewall-cmd --reload

    # Wait for the firewall status to be active
    while [ ! {firewall-cmd --state} ]; do
        sleep 1
    done

    # Create the NFS share
    mkdir -p /nfs/w01

    # Configure the NFS share
    echo "/nfs/w01 *(rw,sync,no_root_squash,no_all_squash,anonuid=\$uid,anongid=\$gid)" >>/etc/exports

    # Enable the NFS server
    systemctl enable --now nfs-server
EOF

# Running scripts on w01
echo "Running scripts on w01"

# Create the NFS share
mkdir -p /nfs/w01

# Add the NFS server to the fstab
echo "s01:/nfs/w01 /nfs/w01 nfs defaults 0 2" >>/etc/fstab

# Mount the NFS share
mount -t nfs s01:/nfs/w01 /nfs/w01

# Create a file on the NFS share
echo "test" >/nfs/w01/test.txt

# Install the web server
yum install httpd -y -q

# Configure the httpd.conf file redirecting the error log to the syslog
echo "ErrorLog syslog:local2" >>/etc/httpd/conf/httpd.conf

# Start the web server
systemctl start httpd

# Wait for the web server status to be active
while [ ! {systemctl status httpd | grep "active (running)"} ]; do
    sleep 1
done

# Generate an autoindex error
curl http://localhost

# Running scripts on s01
echo "Running scripts on s01"
sshpass -p "adminpass" ssh root@s01 -o StrictHostKeyChecking=no /bin/sh <<-EOF
    # Configure s01 to send the error log to the syslog
    echo "local2.* /var/log/httpd_err" >>/etc/rsyslog.conf

    # Restart the syslog
    systemctl restart rsyslog

    # Wait for the syslog to restart
    while [ ! {systemctl status rsyslog | grep "active (running)"} ]; do
        sleep 1
    done
EOF

# Running scripts on w01
echo "Running scripts on w01"

# Generate an autoindex error
curl http://localhost

# Running scripts on s01
echo "Running scripts on s01"
sshpass -p "adminpass" ssh root@s01 -o StrictHostKeyChecking=no /bin/sh <<-EOF
    # Create an Incremental Backup named changes.tar with all files that have changed since the last backup
    tar -cvf /tmp/changes.tar --newer-mtime='1 day ago' /etc

    # install net-tools
	yum install net-tools -y -q

    # Change directories /tmp
	cd /tmp

    # Run the grading script
    ./host_info_t2.sh
EOF

# copy the results
echo "Copying results"
scp -o StrictHostKeyChecking=no -q root@s01:/tmp/s01_report_t2.html /tmp

# open the results
echo "Opening results"
firefox /tmp/s01_report_t2.html &
disown

# exit
echo "Script finished"
exit
