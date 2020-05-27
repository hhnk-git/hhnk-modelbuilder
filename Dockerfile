# Basic isolated python environment.
FROM ubuntu:18.04
RUN apt-get update && apt-get install build-essential python3.8 python3-pip python3-dev python3-setuptools python3-gdal postgresql-client libpq-dev software-properties-common -y --no-install-recommends
RUN add-apt-repository ppa:ubuntugis/ubuntugis-unstable -y
RUN apt-get update && apt-get install gdal-bin -y --no-install-recommends

# Use /code (convention) as the base directory. Install the requirements in
# there.
WORKDIR /code
COPY requirements.txt ./
RUN pip3 install --no-cache-dir -r requirements.txt
COPY . .