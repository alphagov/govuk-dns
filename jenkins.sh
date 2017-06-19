#!/usr/bin/env bash

set -e

case "$1" in
  plan)
    CMD='tf:plan'
    ;;
  apply)
    CMD='tf:apply'
    ;;
  *)
    echo "Didn't recognise argument: must be plan or apply"
    exit 1
esac

git clone 'git@github.com:alphagov/govuk-dns-config.git'

cp govuk-dns-config/$ZONEFILE .

bundle install --path "${HOME}/bundles/${JOB_NAME}"
bundle exec rake generate_terraform
bundle exec rake ${CMD}
