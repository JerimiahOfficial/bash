#!/bin/bash

# WARNING before running:
#   Please make sure you have created Two 2 GB disks on s01.

# Cd to downloads
cd ~/Downloads

# Curl all the files needed for the test
curl -O https://raw.githubusercontent.com/JerimiahOfficial/bash/main/fresh_check.sh
curl -O https://raw.githubusercontent.com/JerimiahOfficial/bash/main/host_info_t1.sh
curl -O https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/wget-1.19.5-10.el8.x86_64.rpm
curl -O https://rpmfind.net/linux/dag/redhat/el7/en/x86_64/dag/RPMS/sshpass-1.05-1.el7.rf.x86_64.rpm

# Chmod downloaded files
chmod +rwx fresh_check.sh
chmod +rwx host_info_t1.sh
chmod +rwx wget-1.19.5-10.el8.x86_64.rpm
chmod +rwx sshpass-1.05-1.el7.rf.x86_64.rpm

# Install wget and sshpass
echo "userpass" | sudo -S -k yum install sshpass-1.05-1.el7.rf.x86_64.rpm -y

# sshpass and scp downloads to s01 and ssh to s01
sshpass -p "adminpass" scp -o StrictHostKeyChecking=no ~/Downloads/{wget*,host*,fresh*} root@s01:/tmp

# sshpass into s01 and run the following commands
sshpass -p "adminpass" ssh root@s01 /bin/sh << EOF
    # Run fresh_check.sh in /tmp
    cd /tmp

    # Chmod +rwx for fresh_check.sh, host_info_t1.sh, wget-1.19.5-10.el8.x86_64.rpm
    chmod +rwx /tmp/fresh_check.sh
    chmod +rwx /tmp/host_info_t1.sh
    chmod +rwx /tmp/wget-1.19.5-10.el8.x86_64.rpm

    # Run fresh_check.sh
    /tmp/fresh_check.sh

    # Create two new users on s01 with user names of: andy and amita
    # Give both new users the initial passwd of mohawk1
    useradd andy
    useradd amita

    # Change the passwd for both new users to mohawk1
    echo "mohawk1" | passwd --stdin andy
    echo "mohawk1" | passwd --stdin amita

    # Force each user to change their passwd the next time they log on.
    passwd -e andy
    passwd -e amita

    # Create a group named web containing andy and amita.
    groupadd web
    usermod -a -G web andy
    usermod -a -G web amita

    # Use the disks you just added to create a new LVM volume group named vgWeb
    pvcreate /dev/sdb /dev/sdc
    vgcreate vgWeb /dev/sdb /dev/sdc

    # Create a single logical volume named /dev/vgWeb/lvol0 using all the space available in vgWeb
    lvcreate -l 100%FREE -n lvol0 vgWeb

    # Build an ext4 file system on /dev/vgWeb/lvol0
    mkfs.ext4 /dev/vgWeb/lvol0

    # Mount the new file system at /mnt/web, this mount must occur autamitically when s01 is rebooted
    mkdir /mnt/web
    mount /dev/vgWeb/lvol0 /mnt/web

    # Add the following line to /etc/fstab:
    # /dev/vgWeb/lvol0 /mnt/web ext4 defaults 0 2
    echo "/dev/vgWeb/lvol0 /mnt/web ext4 defaults 0 2" >> /etc/fstab

    # Configure /mnt/web to be used by the web group to share files.
    chown root:web /mnt/web
    chmod 2770 /mnt/web

    # Install the web server and wget packages on s01
    yum install httpd -y
    yum install /tmp/wget-1.19.5-10.el8.x86_64.rpm -y

    # Configure the web server to start automatically at boot and start the web server
    systemctl enable httpd &
    systemctl start httpd &

    # Configure s01 such that the default web page contains the message, Amita and Andy. Formatting is not important.
    echo "Amita and Andy" > /var/www/html/index.html

    # Create a cron file named /etc/cron.d/web that stops httpd each evening at 23:30 and restarts it the next morning at 07:00.
    echo "30 23 * * * root systemctl stop httpd" > /etc/cron.d/web
    echo "0 7 * * * root systemctl start httpd" >> /etc/cron.d/web

    # run host_info_t1.sh
    /tmp/host_info_t1.sh

    # End of sshpass
EOF

# Scp s01_report_services.html from root's temp directory to your tmp
sshpass -p "adminpass" scp root@s01:/tmp/s01_report_t1.html /tmp

# Open s01_report_services.html with firefox
firefox /tmp/s01_report_t1.html

# End of script
exit 0
