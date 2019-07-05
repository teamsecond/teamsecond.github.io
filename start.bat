@echo off

set host=%1
set port=%2

if [%1] == [] set host=127.0.0.1
if [%2] == [] set port=4000

:done

@echo on

bundle exec jekyll serve --watch --host %host% --port %port% --config _config.yml,_config_dev.yml