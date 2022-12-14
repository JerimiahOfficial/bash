#!/bin/bash -e

# Check if ran as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

# download sshpass
echo "Downloading sshpass"
curl -O https://rpmfind.net/linux/dag/redhat/el7/en/x86_64/dag/RPMS/sshpass-1.05-1.el7.rf.x86_64.rpm
curl -O https://raw.githubusercontent.com/JerimiahOfficial/bash/main/Logging/host_info_log.sh

# install sshpass
echo "Installing sshpass"
yum install sshpass-1.05-1.el7.rf.x86_64.rpm -y -q
while [ ! -f /usr/bin/sshpass ]; do
    sleep 1
done

# notify the user that sshpass is installed
echo "sshpass installed"

# copy over host host_info_log.sh
echo "Copying host_info_log.sh to s01"
sshpass -p "adminpass" scp -o StrictHostKeyChecking=no ./host_info_log.sh root@s01:/tmp/host_info_log.sh

# Running commands on s01 as root
echo "Executing script on s01"
sshpass -p "adminpass" ssh -o StrictHostKeyChecking=no root@s01 /bin/sh <<-EOF
    chmod +x /tmp/host_info_log.sh

    logger -p cron.debug "FM1: This is fake msg from cron with pri=debug"
    logger -p mail.err "FM2: This is fake msg from mail with pri=err"
    logger -p local7.err "FM3: This is fake msg from local7 with pri=err"

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

    #### might change

    # echo "local2.* /var/log/httpd_err" >>/var/log/httpd_err
    # echo "local2.* ~" >>/etc/rsyslog.conf
    # echo "local2.* ~" >>/etc/rsyslog.conf

    # systemctl restart rsyslog

    # while [ "$(systemctl is-active rsyslog)" != "active" ]; do
    #     sleep 1
    # done

    # /tmp/host_info_log.sh
EOF

# Running commands on w01 as root
echo "Executing script on w01"
echo "authpriv.* @@s01:514" >>/etc/rsyslog.conf
systemctl restart rsyslog

while [ "$(systemctl is-active rsyslog)" != "active" ]; do
    sleep 1
done

# Running commands on s01 as root
echo "Executing script on s01"
sshpass -p "adminpass" ssh -o StrictHostKeyChecking=no root@s01 /bin/sh <<-EOF
    firewall-cmd --permanent --add-port=514/tcp
    firewall-cmd --reload

    while [ "$(firewall-cmd --state)" != "running" ]; do
        sleep 1
    done

    sed -i 's/#module(load="imtcp")/module(load="imtcp")/g' /etc/rsyslog.conf
    sed -i 's/#input(type="imtcp" port="514")/input(type="imtcp" port="514")/g' /etc/rsyslog.conf
EOF

# generate authpriv messages on w01
logger -p authpriv.info "FM9: authpriv.info"
logger -p authpriv.warning "FM10: authpriv.warn"
logger -p authpriv.err "FM11: authpriv.err"

# intall httpd on w01
yum install httpd -y -q

while [ ! -f /usr/sbin/httpd ]; do
    sleep 1
done

echo "ErrorLog syslog:local2" >>/etc/httpd/conf/httpd.conf

# start httpd on w01
systemctl start httpd

while [ "$(systemctl is-active httpd)" != "active" ]; do
    sleep 1
done

curl http://localhost

echo "local2.* ~" >>/etc/rsyslog.conf

curl http://localhost

# Running the grading script on s01
echo "Running grading script on s01"
sshpass -p "adminpass" ssh -o StrictHostKeyChecking=no root@s01 /bin/sh <<-EOF
    /tmp/host_info_log.sh
EOF

# scp copy over result from s01
echo "Copying result from s01"
sshpass -p "adminpass" scp -o StrictHostKeyChecking=no root@s01:/root/s01_report_log.html ./s01_report_log.html

# open the result
echo "Opening result"
firefox ./s01_report_log.html &
disown

# Exit
exit 0
