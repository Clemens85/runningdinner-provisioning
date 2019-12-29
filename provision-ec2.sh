#!/usr/bin/env bash

credentialsFolder="/home/clemens/Dev/projects/runningdinner-credentials"

publicServerIp=$(cd aws/ec2-network && terraform output elastic_ip)

logzioToken=$(cat ${credentialsFolder}/logzioToken.txt)

ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook -u ubuntu -i "${publicServerIp}," provision-ec2.yml --extra-vars="logzio_token=${logzioToken}" -vv
