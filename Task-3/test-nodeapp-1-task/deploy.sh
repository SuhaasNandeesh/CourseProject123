echo "Starting to deploy docker image.."
DOCKER_IMAGE=390144862162.dkr.ecr.us-east-1.amazonaws.com/courseproject123:latest
docker pull $DOCKER_IMAGE
#docker ps -q --filter ancestor=$DOCKER_IMAGE | xargs -r docker kill
docker ps -q | xargs -r docker stop
docker run -d -p 8080:8080 $DOCKER_IMAGE