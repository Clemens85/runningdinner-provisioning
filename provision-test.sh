#!/bin/bash

DOCKER_CONTAINER_NAME="ansible-test"

cd dev && docker build -t myubuntu .

docker run -ti --privileged --name $DOCKER_CONTAINER_NAME -d -p 5555:22 myubuntu

cd .. && ansible-playbook -i env/local_docker provision-ec2.yml --extra-vars "os_user=root home_dir=/root logzio_token=XXX" -vv
#--skip-tags=java,update-software-packages
docker stop $DOCKER_CONTAINER_NAME
docker rm $DOCKER_CONTAINER_NAME
