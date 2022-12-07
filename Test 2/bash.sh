#!/bin/bash -e

# array of links to download
links=(
    "https://raw.githubusercontent.com/JerimiahOfficial/bash/main/Utilities/fresh_check.sh"
    "https://raw.githubusercontent.com/JerimiahOfficial/bash/main/Test%202/host_info_t2.sh"
    "https://rpmfind.net/linux/dag/redhat/el7/en/x86_64/dag/RPMS/sshpass-1.05-1.el7.rf.x86_64.rpm"
)

# download dependencies to /tmp
echo "Downloading dependencies"
for link in "${links[@]}"; do
    curl -O $link
done

# install dependencies
echo "Installing dependencies"
echo "userpass" | sudo -S yum install sshpass-1.05-1.el7.rf.x86_64.rpm -y -q

# Wait for the dependencies to install
wait $!

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
    uid=\$(getent passwd alice | cut -d: -f3)
    gid=\$(getent group w01users | cut -d: -f3)

    # Install NFS server
    yum install nfs-utils -y -q

    # Configure the firewall
    firewall-cmd --permanent --add-service=nfs3
    firewall-cmd --reload

    # Wait for the firewall to reload
    wait $!

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

    # Create a file on the NFS share
    echo "test" >/nfs/w01/test.txt

    # Install the web server
    yum install httpd -y -q

    # Wait for the installation to finish
    wait $!

    # Configure the httpd.conf file redirecting the error log to the syslog
    echo "ErrorLog syslog:local2" >>/etc/httpd/conf/httpd.conf

    # Send the local2 log to the s01 syslog
    echo "local2.* @@s01:514" >>/etc/rsyslog.conf

    # Restart the syslog
    systemctl restart rsyslog

    # Wait for the syslog to restart
    wait $!

    # Start the web server
    systemctl start httpd

    # Wait for the web server status to be active
    wait $!

    # Generate an autoindex error
    curl http://localhost
EOF

# Running scripts on s01
echo "Running scripts on s01"
sshpass -p "adminpass" ssh root@s01 -o StrictHostKeyChecking=no /bin/sh <<-EOF
    # Uncomment the tcp config in the rsyslog.conf file
    sed -i 's/#module(load="imtcp")/module(load="imtcp")/g' /etc/rsyslog.conf
    sed -i 's/#input(type="imtcp" port="514")/input(type="imtcp" port="514")/g' /etc/rsyslog.conf

    # Configure s01 to send the error log to the syslog
    echo "local2.* /var/log/httpd_err" >>/etc/rsyslog.conf

    # Restart the syslog
    systemctl restart rsyslog

    # Wait for the syslog to restart
    wait $!
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

    # Wait for the installation to finish
    wait $!

    # Change directories /tmp
	cd /tmp

    # Run the grading script
    ./host_info_t2.sh
EOF

# Change directories to /tmp
cd /tmp

# copy the results
echo "Copying results"
sshpass -p "adminpass" scp -o StrictHostKeyChecking=no -q root@s01:/tmp/s01_report_t2.html /tmp

# open the results
echo "Opening results"
firefox ./s01_report_t2.html &
disown

# exit
echo "Script finished"
exit
