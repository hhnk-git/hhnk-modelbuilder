# hhnk-modelbuilder-temp

Temporary repository for the further development of the modelbuilder (and
datachecker as a preprocessing step). Will be transferred to a permanent
repository when the cookie-cutter is able to create Docker projects


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
