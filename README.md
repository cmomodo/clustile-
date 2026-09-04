# The Game Hub
This will be an application that will move my gaming app to a kubernetes cluster due to high demand.

## System Design
This is a 2048 game. it will be used to show how i used kubernetes to make it scalable for many players. due to high demand, we will be using argocd to update the game configuration. We will have a cicd pipeline to automate the deployment process. This includes building the docker image, pushing it to a registry, and deploying it to the kubernetes cluster. our preferred cloud  provider is AWS.
