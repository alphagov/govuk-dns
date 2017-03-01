# GOV.UK DNS management in Terraform

This uses remote terraform state files (held in S3) to manage configuration.

## Installing Terraform

```
brew update
brew install terraform
```

## Getting SetUp for deployment

### For AWS:

```
export AWS_ACCESS_KEY_ID=<ACCESS_KEY>
export AWS_SECRET_ACCESS_KEY=<SECRET_KEY>
export ROUTE53_ZONE_ID=<ROUTE53_ZONE_ID>
```

### For Dyn:
```
export DYN_CUSTOMER_NAME=<CUSTOMER_NAME>
export DYN_USERNAME=<USERNAME>
export DYN_PASSWORD=<PASSWORD>
export DYN_ZONE_ID=<ZONE_ID>
```

### For Google Cloud DNS:

Download and install the ['Cloud SDK'](https://cloud.google.com/sdk/downloads) and
Kick off the login process with the gcloud CLI by running:

`gcloud init`

Set required environments variables
```
export GOOGLE_MANAGED_ZONE=<MANAGED_ZONE>
export GOOGLE_PROJECT=<PROJECT>
export GOOGLE_REGION=<REGION>
```

## Setting up the Terraform environment

Export the environment variables applicable to your credentials:

```
export DEPLOY_ENV=<environment>
export TF_VAR_account_id=<account_id>
```


## Other environment variables

* DRY_RUN: output the Terraform commands without executing a terraform plan
* BUCKET_NAME: S3 bucket name to store Terraform state file (default 'govuk-terraform-dns-state\-DEPLOY\_ENV)

## Generating Terraform DNS configuration

We can currently generate DNS resource files for three providers:

* Route53
* GCE
* Dyn - *NB* we will be using GCE in preference to Dyn

These files are generated in `tf-tmp/` and follow the naming scheme: `<provider>.tf`.

To generate the configuration files the following environment variables need to be set:

* ZONEFILE: the path to the YAML zone file
* PROVIDERS: which providers to generate resources for, if more than one provider is wanted their names should be separated by commas (default: 'all')
* <PROVIDER>\_ZONE\_ID: for each provider a zone id must be set. For example to produce resources for Dyn the 'DYN\_ZONE\_ID' environment variable must be set.

To generate all resource files:
```
ZONEFILE=<path-to-zone-file> ROUTE53_ZONE_ID=<id> DYN_ZONE_ID=<id> bundle exec rake generate
```

To generate a specific resource file (for example Dyn's):
```
ZONEFILE=<path-to-zone-file> DYN_ZONE_ID=<id> PROVIDERS=dyn bundle exec rake generate
```

## Environment variables for Terraform (explained)

* `DEPLOY_ENV` the environment to deploy to
* `PROVIDERS` which providers to deploy (defaults to `all`)
* `TF_VAR_account_id` the AWS account. The variable is also used when fetching the state file from S3

#### Export the environment applicable to your credentials
For example:
```
export DEPLOY_ENV=test

export PROVIDERS=route53

export TF_VAR_account_id=govuk-infrastructure-test
```

## Show potential changes

```
bundle install
bundle exec rake plan
```

## Apply changes

```
bundle exec rake apply
```

## Making a graph

```
bundle exec rake graph
```

## Creating a fresh environment in AWS

The terraform state is stored in S3 so that it can be shared. To create the bucket build the `dns-tfstate-store` project in [terraform repo](https://github.com/alphagov/govuk-terraform-provisioning)

```bash
TF_VAR_account_id=<Account ID> DEPLOY_ENV=<environment> PROJECT_NAME='dns-tfstate-store'  bundle exec rake plan
```

where `TF_VAR_account_id` is the AWS account to deploy with and `DEPLOY_ENV` is one of `production`, `staging` or `integration`. For more details see the repo.
