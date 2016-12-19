# GOV.UK DNS management in Terraform

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

## Setting up your project

Export the project you're working on as an environment variable (default 'dns')

```
export PROJECT_NAME=<project>
```

## Other environment variables

* REGION: AWS region (default 'eu-west-1')
* SPEC_DIR: directory for spec files (default 'spec')
* DRY_RUN: output the Terraform commands without executing
* BUCKET_NAME: S3 bucket name to store Terraform state file (default 'govuk-terraform-state\-DEPLOY\_ENV)

## Generate Route53 Terraform configuration

Set up the following environment variables:

* ROUTE53\_ZONE\_ID: AWS Route53 zone ID
* ZONEFILE: path to zone file
* TMP_DIR: directory to place the output file (default 'tf-tmp')

```
ROUTE53_ZONE_ID=<zone-id> ZONEFILE=<path-to-zone-file> bundle exec rake generate_route53
```

## Generate Dyn Terraform configuration

Set up the following environment variables:

* DYN\_ZONE\_ID: Dyn zone ID
* ZONEFILE: path to zone file
* TMP_DIR: directory to place the output file (default 'tf-tmp')

```
DYN_ZONE_ID=<zone-id> ZONEFILE=<path-to-zone-file> bundle exec rake generate_dyn
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

# Creating a fresh environment in AWS

Please note this is still experimental.

1. Create the account in AWS
2. Log in and generate root account access keys
3. Export the AWS credentials as environment variables:

   ```
   export AWS_ACCESS_KEY_ID='ACCESS_KEY'
   export AWS_SECRET_ACCESS_KEY='SECRET_KEY'
   ```

4. Export the environment name you wish to create:

   ```
   export DEPLOY_ENV=<environment>
   ```

5. Run the rake task which bootstraps the environment, using the project name
   for the base infrastructure on which you are building on:

  ```
  bundle install
  export PROJECT_NAME=aws_bootstrap
  bundle exec rake bootstrap
  ```

6. This will error the first time, but run it again and it will do the right
   thing.

7. You should now be able to run per project rake tasks as required.
