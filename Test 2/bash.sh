#!/bin/bash -e

# download dependencies
echo "Downloading dependencies"
curl -O https://rpmfind.net/linux/dag/redhat/el7/en/x86_64/dag/RPMS/sshpass-1.05-1.el7.rf.x86_64.rpm
curl -O https://raw.githubusercontent.com/JerimiahOfficial/bash/main/Utilities/fresh_check.sh
curl -O https://raw.githubusercontent.com/JerimiahOfficial/bash/main/Test%202/host_info_t2.sh

# install dependencies
echo "Installing dependencies"
echo "userpass" | sudo -S -k yum install sshpass-1.05-1.el7.rf.x86_64.rpm -y -q >/dev/null

while [ ! -f /usr/bin/sshpass ]; do
    sleep 1
done

# copy fresh_check.sh and host_info_t2.sh to s01
echo "Copying scripts to s01"
sshpass -p "adminpass" scp fresh_check.sh root@s01:/tmp/{fresh_check.sh,host_info_t2.sh} >/dev/null
echo "Scripts copied to s01"

# Running scripts on s01
echo "Running scripts on s01"
sshpass -p "adminpass" ssh root@s01 -o StrictHostKeyChecking=no /bin/sh <<-EOF
    # Run fresh_check.sh
    /tmp/fresh_check.sh

    # Create tar of /etc
    tar -cvf /tmp/etc.tar /etc

    # Create group and user for the NFS server
    groupadd w01users
    useradd alice
    usermod -aG w01users alice

    # Store the uid and gid of the create group and user
    uid=\$(id -u alice)
    gid=\$(id -g w01users)

    # Install NFS server
    yum install nfs-utils -y -q

    # Wait for the NFS server to be installed
    while [ ! -f /usr/sbin/exportfs ]; do
        sleep 1
    done

    # Configure the firewall
    firewall-cmd --permanent --add-service=nfs3
    firewall-cmd --reload

    # Wait for the firewall to finish reloading
    while [ ! -f /usr/bin/firewall-cmd ]; do
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
sshpass -p "adminpass" ssh root@w01 -o StrictHostKeyChecking=no /bin/sh <<-EOF
    # Create the NFS share
    mkdir -p /nfs/w01

    # Add the NFS server to the fstab
    echo "s01:/nfs/w01 /nfs/w01 nfs defaults 0 2" >>/etc/fstab

    # Mount the NFS share
    mount -t nfs s01:/nfs/w01 /nfs/w01

    # Wait for the NFS share to be mounted
    while [ ! -d /nfs/w01 ]; do
        sleep 1
    done

    # Create a file on the NFS share
    echo "test" >/nfs/w01/test.txt

    # Install the web server
    yum install httpd -y -q

    # Wait for the web server to be installed
    while [ ! -f /usr/sbin/httpd ]; do
        sleep 1
    done

    # Configure the httpd.conf file redirecting the error log to the syslog
    echo "ErrorLog syslog:local2" >>/etc/httpd/conf/httpd.conf

    # Start the web server
    systemctl start httpd

    # Wait for the web server to start
    while [ ! -f /usr/sbin/httpd ]; do
        sleep 1
    done
    
    # Generate an autoindex error
    curl http://localhost
EOF

# Running scripts on s01
echo "Running scripts on s01"
sshpass -p "adminpass" ssh root@s01 -o StrictHostKeyChecking=no /bin/sh <<-EOF
    # Configure s01 to send the error log to the syslog
    echo "local2.* /var/log/httpd_err" >>/etc/rsyslog.conf

    # Restart the syslog
    systemctl restart rsyslog

    # Wait for the syslog to restart
    while [ ! -f /usr/sbin/rsyslogd ]; do
        sleep 1
    done
EOF

# Running scripts on w01
echo "Running scripts on w01"
sshpass -p "adminpass" ssh root@w01 -o StrictHostKeyChecking=no /bin/sh <<-EOF
    # Generate an autoindex error
    curl http://localhost
EOF

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
scp -o StrictHostKeyChecking=no root@s01:/tmp/s01_report_t2.html /tmp >/dev/null

# open the results
echo "Opening results"
firefox /tmp/s01_report_t2.html &
disown

# exit
echo "Script finished"
exit
