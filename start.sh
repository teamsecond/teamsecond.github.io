#!/bin/bash

function usage {
   echo "USAGE: not supported yet";
   exit 0;
}

PARAM="h:p:u";

unset HOST
unset PORT

while getopts $PARAM opt; do
  case $opt in
    h)
        HOST=$OPTARG;
        ;;
    p)
        PORT=$OPTARG;
        ;;
    u)
        usage;
        ;;
    *)
         ## default
         usage;
         exit 1;
  esac
done

if [ -z "$HOST" ]; then
	HOST="127.0.0.1"
fi

if [ -z "$PORT" ]; then
	PORT="4000"
fi

bundle exec jekyll serve --watch --host "$HOST" --port "$PORT" --config _config.yml,_config_dev.yml