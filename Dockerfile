FROM ubuntu:18.04
RUN apt-get update && apt-get install build-essential python3.8 python3-pip python3-dev python3-setuptools gdal-bin python3-gdal libgdal-dev postgresql-client libpq-dev libsqlite3-mod-spatialite git locales software-properties-common -y --no-install-recommends
RUN add-apt-repository ppa:ubuntugis/ubuntugis-unstable -y
RUN apt-get update && apt-get install gdal-bin -y --no-install-recommends

# GDAL installation on linux
RUN export CPLUS_INCLUDE_PATH=/usr/include/gdal
RUN export C_INCLUDE_PATH=/usr/include/gdal

# Use /code (convention) as the base directory. Install the requirements in
# there.
WORKDIR /code

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

COPY requirements.txt ./
RUN pip3 install --no-cache-dir -r requirements.txt
COPY . .


# raster tools for line-up # not needed since it is hard-coded.
#<<<<<<< Updated upstream
#RUN pip3 install --upgrade setuptools==58.0.2 --no-cache-dir wheel && pip3 install pip==10.0.1 pipenv==2018.5.18
#RUN git clone https://github.com/nens/raster-tools.git
#WORKDIR /code/raster-tools
#RUN git checkout emiel-hhnk
#RUN PIPENV_VENV_IN_PROJECT=1 pipenv install --dev
#ENV PATH="/code/raster-tools/.venv/bin:${PATH}"
#=======
#RUN pip3 install --upgrade setuptools wheel && pip3 install pip==10.0.1 pipenv==2018.5.18
#RUN git clone https://github.com/nens/raster-tools.git
#WORKDIR /code/raster-tools
# RUN git checkout emiel-hhnk
#RUN PIPENV_VENV_IN_PROJECT=1 pipenv install 
#--dev
#ENV PATH="/code/raster-tools/.venv/bin:${PATH}"
#>>>>>>> Stashed changes

# Back to default workdir and install packages in new env (check if this can be removed later)
WORKDIR /code
