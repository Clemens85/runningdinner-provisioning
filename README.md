**Credentials**

AWS Credentials for technical user on app server and token for logzio account are not part of repository
and must be specified by variables (-> provision-ec2.sh and/or provision-ec2.yml)

**Steps**

1. Execute `terraform apply` in aws folder for setting up AWS resources
2. Build runningdinner app artefacts in Jenkins (these are copied into local artefacts folder)
3. Execute `provision-ec2.sh` (adapt folder to credentials if needed)
4. Switch Route53 DNS to ElasticIp by calling `switch_dns_to_new_server.sh`

**Local testing**

Ansible provisioning of EC2 app server can be tested locally by using Docker image (-> dev folder).
Just execute `provision-test.sh` (which must maybe adapted... 
if you want to check out the provisioning state, just remove the lines which delete the created docker container again).

