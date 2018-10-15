#!/bin/bash -x

INTERFACE=$(route | grep '^default' | grep -o '[^ ]*$')

echo "Starting Build Process"

echo "Disable SELinux ..."

setenforce 0

echo "Reset DNS settings ..."

echo "supersede domain-name-servers 1.1.1.1, 9.9.9.9;" >> /etc/dhcp/dhclient.conf

dhclient -r -v $INTERFACE && rm /var/lib/dhclient/dhclient.* ; dhclient -v $INTERFACE

echo "Fully update ..."

yum -y update

echo "Install packages we need ..."

yum install -y amazon-linux-extras yum-utils device-mapper-persistent-data lvm2
yum-config-manager --enable extras
amazon-linux-extras install docker -y

echo "Enable docker ..."

systemctl enable docker
systemctl start docker

echo "Install and get info for Outline Server ..."

bash -c "$(wget -qO- https://raw.githubusercontent.com/Jigsaw-Code/outline-server/master/src/server_manager/install_scripts/install_server.sh)" > /var/log/outline-install.log

echo "#####" > /tmp/outline-install-details.txt
grep "apiUrl" /var/log/outline-install.log >> /tmp/outline-install-details.txt
export VPN_PORT=$(docker logs shadowbox | grep "tcp server listening" | sed 's/.*0:\(.*\)/\1/')
export MGMT_PORT=$(grep apiUrl /tmp/outline-install-details.txt | sed -r 's/.*[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:([0-9]*).*/\1/g')
echo "#####" >> /tmp/outline-install-details.txt
echo -e "\033[0;31mManagement TCP/UDP port number: $MGMT_PORT\033[0m" >> /tmp/outline-install-details.txt
echo -e "\033[0;33mAccess TCP/UDP port number: $VPN_PORT\033[0m" >> /tmp/outline-install-details.txt
echo "#####" >> /tmp/outline-install-details.txt

echo "Update security group \"${SECURITY_GROUP}\" to permit VPN Ingress on $MGMT_PORT and $VPN_PORT ..."

aws --region ${REGION} ec2 authorize-security-group-ingress --group-name ${SECURITY_GROUP} --ip-permissions IpProtocol=tcp,FromPort=$MGMT_PORT,ToPort=$MGMT_PORT,IpRanges='[{CidrIp=0.0.0.0/0}]',Ipv6Ranges='[{CidrIpv6=::/0}]'
aws --region ${REGION} ec2 authorize-security-group-ingress --group-name ${SECURITY_GROUP} --ip-permissions IpProtocol=udp,FromPort=$MGMT_PORT,ToPort=$MGMT_PORT,IpRanges='[{CidrIp=0.0.0.0/0}]',Ipv6Ranges='[{CidrIpv6=::/0}]'

aws --region ${REGION} ec2 authorize-security-group-ingress --group-name ${SECURITY_GROUP} --ip-permissions IpProtocol=tcp,FromPort=$VPN_PORT,ToPort=$VPN_PORT,IpRanges='[{CidrIp=0.0.0.0/0}]',Ipv6Ranges='[{CidrIpv6=::/0}]'
aws --region ${REGION} ec2 authorize-security-group-ingress --group-name ${SECURITY_GROUP} --ip-permissions IpProtocol=udp,FromPort=$VPN_PORT,ToPort=$VPN_PORT,IpRanges='[{CidrIp=0.0.0.0/0}]',Ipv6Ranges='[{CidrIpv6=::/0}]'

echo "DONE!"
