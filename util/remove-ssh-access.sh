#!/bin/bash
# see https://blog.cloudinvaders.com/add-your-ip-address-to-an-ec2-security-group-from-command-line/
export IP=`curl -s https://api.ipify.org`
echo $IP
aws ec2 revoke-security-group-ingress --group-id sg-0d5014d3e4c3238f2 --protocol tcp --port 22 --cidr $IP/32