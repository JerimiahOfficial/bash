#!/bin/bash

# change to the directory where the script is located
cd ~/Downloads

# download sshpass
curl -O https://rpmfind.net/linux/dag/redhat/el7/en/x86_64/dag/RPMS/sshpass-1.05-1.el7.rf.x86_64.rpm

# install sshpass
echo "userpass" | sudo -S yum install -y sshpass-1.05-1.el7.rf.x86_64.rpm

# copy over host host_info_log.sh
sshpass -p "adminpass" scp -o StrictHostKeyChecking=no ./host_info_log.sh root@s01:/root/host_info_log.sh

# Running commands on s01 as root
sshpass -p "adminpass" ssh -o StrictHostKeyChecking=no root@s01 /bin/sh <<EOF
    # Part A:
    logger -p cron.debug "FM1: This is fake msg from cron with pri=debug"
    logger -p mail.err "FM2: This is fake msg from mail with pri=err"
    logger -p local7.err "FM3: This is fake msg from local7 with pri=err"

    # Part B:
    cp /etc/rsyslog.conf /etc/rsyslog.conf.prev

    echo "mail.* /var/log/mail_warn.log" >>/etc/rsyslog.conf
    echo "*.err /var/log/msg_err.log" >>/etc/rsyslog.conf

    systemctl restart rsyslog

    while [ "$(systemctl is-active rsyslog)" != "active" ]; do
        sleep 1
    done
    
    logger -p mail.err "FM4: mail.err"
    logger -p mail.warning "FM5: mail.warn"
    logger -p mail.debug "FM6: mail.debug"
    logger -p cron.warning "FM7: cron.warn"
    logger -p cron.err "FM8: cron.err"

    # Part C:
    echo "module(load=\"imtcp\") # needs to be done just once" >>/etc/rsyslog.conf
    echo "input(type=\"imtcp\" port=\"514\")" >>/etc/rsyslog.conf

    firewall-cmd --permanent --add-port=514/tcp
    firewall-cmd --reload

    # Part D:
    echo "local2.* /var/log/httpd_err" >>/var/log/httpd_err

    # Part E:
    echo "local2.* ~" >>/etc/rsyslog.conf
    echo "local2.* ~" >>/etc/rsyslog.conf
EOF

# Running commands on w01 as alice
# Part C:
echo "authpriv.* @@s01:514" >>/etc/rsyslog.conf

# Part D:
echo "userpass" | yum install -y httpd

echo "ErrorLog syslog:local2" >>/etc/httpd/conf/httpd.conf

systemctl start httpd

curl http://localhost

# Part E:
echo "local2.* ~" >>/etc/rsyslog.conf

curl http://localhost/doesnotexist
