#!/usr/bin/env bash

set -e

case "$1" in
  plan)
    CMD=plan
    ;;
  apply)
    CMD=apply
    ;;
  *)
    echo "Didn't recognise argument: must be plan or apply"
    exit 1
esac

git clone 'git@github.digital.cabinet-office.gov.uk:gds/govuk-dns-config.git'

cp govuk-dns-config/$ZONEFILE .

bundle install --path "${HOME}/bundles/${JOB_NAME}"
bundle exec rake generate
bundle exec rake ${CMD}
