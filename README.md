# hhnk-modelbuilder

Temporary repository for the further development of the modelbuilder (and
datachecker as a preprocessing step). Will be transferred to a permanent
repository when the cookie-cutter is able to create Docker projects

## Usage

Pull the latest code from this repository using git/GitHub desktop.

On command line (cmd on Windows) browse to the repository location

`docker-compose build` builds the image as defined by the `Dockerfile`

`docker-compose up -d` starts the containers in daemon mode. Webinterface is now available through http://localhost:5000. The polder id field for the model builder corresponds with the polder_id field in the poldercluster layer in the HDB. The polder name is used for filenames.

Make sure you have your input data ready within the `data` folder (see section below) before running the datachecker or modelbuilder.

## Command line usage

`docker-compose run hhnk bash` runs the hhnk image in the container and brings you to the command line from which you can start the datachecker or the modelbuilder. You can replace `bash` with any command to execute that command directly.

To run the datachecker either run `python3 /code/datachecker/datachecker.py` from within the container, or run the image directly with the datachecker command: `docker-compose run hhnk python3 /code/datachecker/datachecker.py`

The modelbuilder has to be initialized with 2 variables, the `polder_id` and the `polder_name`. The `polder_id` is used to select data from the datachecker within the polder which id you supply, the `polder_name` is used in the output filenames (`.sqlite`, `.tif`). To run the modelbuilder use for example `python3 /code/modelbuilder/modelbuilder.py 15 starnmeer` from within the container or start the container like this `docker-compose run hhnk python3 /code/modelbuilder/modelbuilder.py 15 starnmeer`

To stop the container run `docker-compose stop`.

Periodically, run `docker system prune` to clean up old stuff.

## Data
If you don't specify any location for the input, output and fixed data it will bind the `data` directory within your github folder on your PC.
Make sure that the folder exists with at least the following data:

```bash
data
├───fixed_data
│   ├───datamining_ahn3
│   ├───DEM
│   │   └───dem_floor_5cm
│   ├───hydroobjectid
│   └───other
└───input
    ├───DAMO.gdb
    └───HDB.gdb
```


## Data

To connect to the postgis database use the following settings:

	host: localhost
	port: 55550
	database: datachecker
	username: postgres
	password: "same as username"

## Development

`docker-compose pull` to grab the images.

`docker-compose build` to build the image as defined by the `Dockerfile`.

`docker-compose up -d` to start everything in "daemon" mode. The "hhnk" docker
will exit as it isn't a service that stays up, which is fine.

`docker-compose run hhnk SOMETHING` runs "SOMETHING" on the commandline of the
hhnk docker. "bash", "python", etc.

For instance: `docker-compose run hhnk psql -h db -U postgres`
Or: `docker-compose run hhnk psql -h db -U postgres -f sql/example.sql`


Afterwards, `docker-compose stop` to stop everything.

Periodically, run `docker system prune` to clean up old stuff.


## Using production settings

First things first: create an access token at
https://github.com/settings/tokens, give it just "read:packages"
permission. Remember the token somewhere.

`docker login docker.pkg.github.com -u your-github-username` and give it the
token as a password.

Then you can use the same docker-compose commands as mentioned above, but with
an extra `-f docker-compose.deploy.yml`. Note: you don't need to build as
you'll grab the github-actions-build image instead:

	docker-compose -f docker-compose.deploy.yml pull
	docker-compose -f docker-compose.deploy.yml up -d
	docker-compose -f docker-compose.deploy.yml run hhnk bash
	docker-compose -f docker-compose.deploy.yml stop

## Python packages
In the `requirements.txt` file the python packages (including version number) that are installed at build are noted. Amongst others there is the `threedi-modelchecker`. The modelchecker checks the output `.sqlite` one last time on errors. The version of the modelchecker expects a specific 3Di database structure. When updating the `threedi-modelchecker` you might also have to update the 3Di database template, and possibly edit some of the scripts filling the 3Di database and vica versa.

## Known issues
Pulling from GitHub on Windows sometimes the line endings of the .sh files, causing the datachecker/modelbuilder to crash. Line-endings of .sh files should always be Unix (LF). Using Notepad++ this can be changed (right-bottom toolbar). This should be fixed now with the use of .gitattribute. When creating a new .sh file, make sure to select the Unix (LF) line ending.

During docker build the fixed data folder is copied which lead to an 'no space left on device error:

	Step 10/18 : COPY . .
	ERROR: Service 'hhnk' failed to build: Error processing tar file(exit status 1): write /code/data/fixed_dpace left on device

This is due to limited space on the HHNK test server. The fixed data is actually on the network directory. Place the DEM folder to a temporary location and place is back after the docker is build.

During starting the web service a folder is accessed. This gives an permission denieud error:

	ERROR: for hhnk  Cannot start service hhnk: error while creating mount source path '[...]/hhnk-modelbuilder-master/tools: permission denied

The folder is created, but perhaps not quickly enough. Retry the docker-compose up -d command.

