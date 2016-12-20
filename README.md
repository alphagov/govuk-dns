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

We can currently generate DNS resource files for two providers: **Route53** and **Dyn**.

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
ZONEFILE=<path-to-zone-file> DYN_ZONE_ID=<id> PROVIDERS=Dyn bundle exec rake generate
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
  bundle exec rake bootstrap
  ```

6. This will error the first time, but run it again and it will do the right
   thing.

7. You should now be able to run per project rake tasks as required.
