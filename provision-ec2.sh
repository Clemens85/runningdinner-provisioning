#!/usr/bin/env bash

if [[ $# -lt 1 ]] ; then
  echo "Need to pass path of folder where credentials are located"
  exit -1
fi

credentialsFolder=$1

publicServerIp=$(cd aws/ec2-network && terraform output elastic_ip)

logzioToken=$(cat ${credentialsFolder}/logzioToken.txt)

ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook -u ubuntu -i "${publicServerIp}," provision-ec2.yml --extra-vars="logzio_token=${logzioToken}" -vv
