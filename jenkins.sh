#!/usr/bin/env bash

set -e
export ZONEFILE=publishing.service.gov.uk.yaml

git clone 'git@github.gds:gds/govuk-dns-config.git'

cp govuk-dns-config/$ZONEFILE .

bundle install --path "${HOME}/bundles/${JOB_NAME}"
bundle exec rake generate
bundle exec rake plan
