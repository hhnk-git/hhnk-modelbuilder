# Basic isolated python environment.
FROM ubuntu:18.04
RUN apt-get update && apt-get install build-essential python3.8 python3-pip python3-dev python3-setuptools python3-gdal libgdal-dev postgresql-client libpq-dev git locales software-properties-common -y --no-install-recommends
RUN add-apt-repository ppa:ubuntugis/ubuntugis-unstable -y
RUN apt-get update && apt-get install gdal-bin -y --no-install-recommends

# Use /code (convention) as the base directory. Install the requirements in
# there.
WORKDIR /code

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

COPY requirements.txt ./
RUN pip3 install --no-cache-dir -r requirements.txt
RUN pip3 install --upgrade setuptools wheel && pip3 install pip==10.0.1 pipenv==2018.5.18
COPY . .
RUN git clone https://github.com/nens/raster-tools.git
WORKDIR /code/raster-tools
RUN git checkout emiel-hhnk
#RUN PIPENV_VENV_IN_PROJECT=1 pipenv sync --dev
WORKDIR /code