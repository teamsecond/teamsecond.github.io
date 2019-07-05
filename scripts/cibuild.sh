#!/bin/bash

set -e # halt script on error

# deployment
if [ "$TRAVIS_PULL_REQUEST" == "false" ]; then 
	BRANCH=$TRAVIS_BRANCH

# pull request
else

	if [ "$TRAVIS_BRANCH" == "master" ]; then # production
		rake build:prod
		
	elif [ "$TRAVIS_BRANCH" == "source" ]; then # source
		rake build:dev
		# bundle exec htmlproofer ./_site --disable-external
	else
		BRANCH=$TRAVIS_PULL_REQUEST_BRANCH
	fi
	
fi