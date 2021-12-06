FROM ubuntu:18.04

ENV TERM linux
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
apt-get install build-essential -y

RUN apt-get install wget -y
RUN apt-get install -y curl
RUN apt-get install -y awscli
RUN apt-get install -y mysql-client
RUN wget https://github.com/stripe/stripe-cli/releases/download/v1.7.8/stripe_1.7.8_linux_x86_64.tar.gz && \
tar -xvf stripe_1.7.8_linux_x86_64.tar.gz -C /usr/local/bin
RUN apt-get install -y jq
RUN apt-get install -y zip
RUN apt-get install -y software-properties-common && \
add-apt-repository ppa:deadsnakes/ppa && \
apt-get update && \
apt-get install -y python3.9


WORKDIR /root/code
