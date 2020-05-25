# Basic isolated python environment.
FROM python:3.8

# Use /code (convention) as the base directory. Install the requirements in
# there.
WORKDIR /code
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . .