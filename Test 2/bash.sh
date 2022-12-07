#!/bin/bash -e

start=$(date +%s)
links=(
    "https://raw.githubusercontent.com/JerimiahOfficial/bash/main/Utilities/fresh_check.sh"
    "https://raw.githubusercontent.com/JerimiahOfficial/bash/main/Test%202/host_info_t2.sh"
    "https://rpmfind.net/linux/dag/redhat/el7/en/x86_64/dag/RPMS/sshpass-1.05-1.el7.rf.x86_64.rpm"
)

echo "Downloading dependencies"
for link in "${links[@]}"; do
    curl -s -O $link
done

echo "Installing dependencies"
echo "userpass" | sudo -n -S yum install sshpass-1.05-1.el7.rf.x86_64.rpm -y -q
echo "Copying scripts to s01"

chmod +x ./fresh_check.sh ./host_info_t2.sh
sshpass -p "adminpass" scp -o StrictHostKeyChecking=no -q ~/Downloads/{fresh_check.sh,host_info_t2.sh} root@s01:/tmp/

echo "Running script"
sshpass -p "adminpass" ssh root@s01 -o StrictHostKeyChecking=no /bin/sh <<-EOF
    cd /tmp

    ./fresh_check.sh

    tar -C / -cf etc.tar etc

    groupadd w01users
    useradd alice

    # Store the uid and gid of the create group and user
    uid=\$(getent passwd alice | cut -d: -f3)
    gid=\$(getent group w01users | cut -d: -f3)

    yum install nfs-utils -y -q

    firewall-cmd --permanent --add-service=nfs3
    firewall-cmd --reload

    mkdir -p /nfs/w01

    chown alice:w01users /nfs/w01
    chmod 2777 /nfs/w01

    echo "/nfs/w01 *(rw,sync,all_squash,anonuid=\$uid,anongid=\$gid)" >>/etc/exports

    systemctl enable --now nfs-server
EOF

sshpass -p "adminpass" ssh root@w01 -o StrictHostKeyChecking=no /bin/sh <<-EOF
    mkdir -p /nfs/w01

    echo "s01:/nfs/w01 /nfs/w01 nfs defaults 0 2" >>/etc/fstab

    mount -t nfs s01:/nfs/w01 /nfs/w01

    echo "test" >/nfs/w01/test.txt

    yum install httpd -y -q

    # Modify the httpd config file, httpd.conf to send error messages to syslog with the facility local2
    sed -i 's/ErrorLog "logs\/error_log"/ErrorLog syslog:local2/g' /etc/httpd/conf/httpd.conf

    systemctl start httpd
EOF

sshpass -p "adminpass" ssh root@s01 -o StrictHostKeyChecking=no /bin/sh <<-EOF
    yum install net-tools -y -q

    firewall-cmd --permanent --add-port=514/tcp
    firewall-cmd --reload

    # Enable remote logging via TCP on s01
    sed -i 's/#module(load="imtcp")/module(load="imtcp")/g' /etc/rsyslog.conf
    sed -i 's/#input(type="imtcp" port="514")/input(type="imtcp" port="514")/g' /etc/rsyslog.conf

    # Modify rsyslog.conf on s01 to send all messages with a facility of local2 to /var/log/httpd.err
    echo "local2.* /var/log/httpd.err" >>/etc/rsyslog.conf

    systemctl restart rsyslog
EOF

sshpass -p "adminpass" ssh root@w01 -o StrictHostKeyChecking=no /bin/sh <<-EOF
    # Modify rsyslog.conf on w01 to send all messages with a facility of local2 to s01
    echo "local2.* @@s01" >>/etc/rsyslog.conf

    systemctl restart rsyslog

    curl -s -o /dev/null http://localhost

    logger -p local2.info "This is a test message"
    logger -p local2.warning "This is a test message"
    logger -p local2.err "This is a test message"
EOF

sshpass -p "adminpass" ssh root@s01 -o StrictHostKeyChecking=no /bin/sh <<-EOF
	cd /tmp

    # Create an Incremental Backup
    tar -C / -cf ./changes.tar --newer-mtime='1 day ago' etc

    ./host_info_t2.sh
EOF

cd /tmp

echo "Copying results"
sshpass -p "adminpass" scp -o StrictHostKeyChecking=no -q root@s01:/tmp/s01_report_t2.html /tmp

echo "Opening results"
firefox ./s01_report_t2.html &
disown

end=$(date +%s)
runtime=$((end - start))
echo "Time taken: $runtime seconds"

# exit
exit 0
