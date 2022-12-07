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

sshpass -p "adminpass" ssh root@s01 -o StrictHostKeyChecking=no /bin/sh <<-EOF
    tar -cvf /tmp/etc.tar /etc

    groupadd w01users
    useradd alice
    usermod -aG w01users alice

    uid=\$(id -u alice)
    gid=\$(id -g w01users)

    yum install nfs-utils -y -q

    while [ ! -f /usr/sbin/exportfs ]; do
        sleep 1
    done

    firewall-cmd --permanent --add-service=nfs3
    firewall-cmd --reload

    while [ ! -f /usr/bin/firewall-cmd ]; do
        sleep 1
    done

    mkdir -p /nfs/w01

    echo "/nfs/w01 *(rw,sync,no_root_squash,no_all_squash,anonuid=\$uid,anongid=\$gid)" >>/etc/exports

    systemctl enable --now nfs-server
EOF

sshpass -p "adminpass" ssh root@w01 -o StrictHostKeyChecking=no /bin/sh <<-EOF
    mkdir -p /nfs/w01

    echo "s01:/nfs/w01 /nfs/w01 nfs defaults 0 2" >>/etc/fstab

    mount -t nfs s01:/nfs/w01 /nfs/w01

    echo "test" >/nfs/w01/test.txt

    yum install httpd -y

    echo "ErrorLog syslog:local2" >>/etc/httpd/conf/httpd.conf

    systemctl start httpd

    curl http://localhost
EOF

sshpass -p "adminpass" ssh root@s01 -o StrictHostKeyChecking=no /bin/sh <<-EOF
    echo "local2.* /var/log/httpd_err" >>/etc/rsyslog.conf

    systemctl restart rsyslog
EOF

sshpass -p "adminpass" ssh root@w01 -o StrictHostKeyChecking=no /bin/sh <<-EOF
    curl http://localhost

    tar -cvf /tmp/changes.tar -N /tmp/etc.tar /etc

EOF
