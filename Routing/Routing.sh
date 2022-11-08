#!/bin/bash

# Networks
#
# Blue
# 10.1.1.0/24
# enp0s8: 10.1.1.10
# enps0s3: 10.1.1.20
# enps0s3: 10.1.1.1
#
# Yellow
# 10.2.1.0/24
# enp0s8: 10.2.1.1
# enps0s3: 10.2.1.30

# hosts files must be updated as appropriate. With host names r01yellow and r01blue configured.
echo "10.2.1.1 r01yellow" >>/etc/hosts
echo "10.1.1.1 r01blue" >>/etc/hosts

# Add a route to the blue for w01
echo "10.1.1.1 r01" >>/etc/hosts

# Add a route to the yellow for s02
echo "10.2.1.1 r01" >>/etc/hosts

# enable ip forwarding
sysctl -w net.ipv4.ip_forward=1

# disable the firewall
systemctl disable firewalld
systemctl stop firewalld

# Add a default gateway to y01
ip route add default via

# install the iproute package
yum install -y iproute

# restart the interfaces
nmcli connection up enp0s8
nmcli connection up enp0s3

# set the hostname to r01
hostnamectl set-hostname r01

# set the hostname to s02
hostnamectl set-hostname s02

# reboot the system
systemctl reboot

# We have a new connection named 'Wired connection 1', let's rename it enp0s8 to be consistent
nmcli connection modify 'Wired connection 1' connection.id enp0s8
nmcli connection modify enp0s8 ipv4.addresses 10.2.1.20/24
nmcli connection modify enp0s8 ipv4.method manual
nmcli connection modify enp0s8 ipv6.method disable
nmcli connection up enp0s8
