#!/usr/bin/env bash

elasticIp=$(../aws/terraform output elastic_ip)
sed 's/__EIP__/${elasticIp}/g' switch-dns-to-new-server.json.template > switch-dns-to-new-server.json

aws route53 change-resource-record-sets --hosted-zone-id ZX9JVHNHZRJLS --change-batch file://switch-dns-to-new-server.json
