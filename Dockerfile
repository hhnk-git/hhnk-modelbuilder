# Basic isolated python environment.
<<<<<<< Updated upstream
FROM python:3.8
=======
FROM ubuntu:18.04
RUN apt-get update && apt-get install build-essential python3.8 python3-pip python3-dev python3-setuptools python3-gdal postgresql-client libpq-dev -y --no-install-recommends
>>>>>>> Stashed changes

# Use /code (convention) as the base directory. Install the requirements in
# there.
WORKDIR /code
COPY requirements.txt ./
<<<<<<< Updated upstream
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
=======
RUN pip3 install --no-cache-dir -r requirements.txt
COPY . .
>>>>>>> Stashed changes
