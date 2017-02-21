# GOV.UK DNS management in Terraform

This uses remote terraform state files (held in S3) to manage configuration.

## Installing Terraform

```
brew update
brew install terraform
```

## Setting up credentials

Export your AWS credentials as environment variables:

```
export AWS_ACCESS_KEY_ID='ACCESS_KEY'
export AWS_SECRET_ACCESS_KEY='SECRET_KEY'
```

## Setting up the environment

Export the environment applicable to your credentials:

```
export DEPLOY_ENV=<environment>
```

## Other environment variables

* REGION: AWS region (default 'eu-west-2')
* DRY_RUN: output the Terraform commands without executing
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

Each provider requires certain environment variables be set in order to generate the terraform

* Route52
  - ROUTE53_ZONE_ID - Where to deploy
  - AWS_ACCESS_KEY_ID - Credentials to deploy with
  - AWS_SECRET_ACCESS_KEY - Credentials' secret
* GCE
  - GCE_ZONE_ID - where to deploy
  - GCE_CREDENTIALS - JSON file holding the credentials for a [google service account](https://cloud.google.com/compute/docs/access/create-enable-service-accounts-for-instances)
  - GCE_REGION - Region to deploy to (e.g. `europe-west1-d`)
* Dyn
  - DYN_ZONE_ID - where to deploy
  - DYN_CUSTOMER_NAME - name of the customer
  - DYN_USERNAME - the specific user deploy
  - DYN_PASSWORD - the user's password

## Environment variables for terraform

* `DEPLOY_ENV` the environment to deploy to
* `PROVIDERS` which providers to deploy (defaults to `all`)
* `TF_VAR_account_id` AWS access key to use to fetch the state from S3

If deploying to GCE make sure the GCE credentials file referred to by `GCE_CREDENTIALS` is present & correct.

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
