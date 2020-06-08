FROM ubuntu:trusty

MAINTAINER sander.smits@nelen-schuurmans.nl

ENV REFRESHED_AT 20170105_1147

RUN export DEBIAN_FRONTEND=noninteractive

ENV DEBIAN_FRONTEND noninteractive
ENV PYTHONUNBUFFERED 1

RUN apt-get update && apt-get install -y --force-yes \
  libgeos-dev \
  libpq-dev \
  python-dev \
  python-pip \
&& rm -rf /var/lib/apt/lists/*

COPY requirements.txt /requirements.txt
RUN pip install -r /requirements.txt

COPY ./compose/default_config.ini /srv/default_config.ini

COPY ./compose/start.sh /start.sh
RUN sed -i 's/\r//' /start.sh
RUN chmod +x /start.sh

WORKDIR /srv
