# GOV.UK DNS

GOVUK DNS is a tool to deploy DNS zones from configuration in YAML to multiple DNS providers.

It uses [Terraform](https://www.terraform.io/) for deployment, and uses [Amazon S3](https://aws.amazon.com/s3/) to store Terraform remote state.

Configuration for deployment is configured using environment variables for allow easier integration with a deployment tool such as [Jenkins](https://jenkins.io/).

## Providers

Our currently supported providers are:

[Amazon Route 53](https://aws.amazon.com/route53/)
[Google Cloud DNS](https://cloud.google.com/dns/)
[Dyn DNS](http://dyn.com/dns/)

## Install Terraform

Terraform is required to deploy changes. On MacOS, you can use [Homebrew](https://brew.sh/)
to install:

```
brew update
brew install terraform
```

For other operating systems check the [Terraform documentation](https://www.terraform.io/intro/getting-started/install.html).

## Create an Amazon S3 bucket

We use Amazon S3 to store the Terraform state. Check the [documentation to create an S3 bucket](http://docs.aws.amazon.com/AmazonS3/latest/gsg/CreatingABucket.html).

## Zonefile format

The format for the zonefile is in YAML and should look like this:

```
---
origin: example.com.
records:
- record_type: CNAME
  subdomain: foo
  ttl: '300'
  data: foo.example.com.
- record_type: A
  subdomain: www
  ttl: '300'
  data: 1.2.3.4
- record_type: TXT
  subdomain: my-txt-record
  ttl: '3600'
  data: thisismytxtdata
```

## Preparing configuration for deployment

## All vendors

We require setting AWS credentials for all vendors for use with Terraform remote
state in Amazon S3.

```
export AWS_ACCESS_KEY_ID=<ACCESS_KEY>
export AWS_SECRET_ACCESS_KEY=<SECRET_KEY>
```

Set the S3 bucket name:

```
export BUCKET_NAME=my-super-cool-bucket
```

We set the env var below to reference between different states for different
environments as this is good practice in Terraform:

`export DEPLOY_ENV=<environment>`

Set the location of the zonefile:

```
export ZONEFILE=/path/to/example.com.yaml
```

Finally, set which provider you wish to deploy to. The options are:
 - route53
 - gce
 - dyn

```
export PROVIDERS=route53
```

### AWS

```
export ROUTE53_ZONE_ID=<ROUTE53_ZONE_ID>
```

### Google Cloud DNS

Google Cloud requires interacting using [service accounts](https://cloud.google.com/compute/docs/access/service-accounts). This is the file that is referenced as `GOOGLE_CREDENTIALS`.

```
export GOOGLE_ZONE_NAME=<MANAGED_ZONE>
export GOOGLE_DNS_NAME=<DOMAIN_NAME>
export GOOGLE_PROJECT=<PROJECT>
export GOOGLE_REGION=<REGION>
export GOOGLE_CREDENTIALS=`cat <PATH TO CREDENTIALS FILE>`
```

### Dyn

```
export DYN_CUSTOMER_NAME=<CUSTOMER_NAME>
export DYN_USERNAME=<USERNAME>
export DYN_PASSWORD=<PASSWORD>
export DYN_ZONE_ID=<ZONE_ID>
```

## Deployment Process

Our tool generates Terraform configuration as JSON. These files are generated
in `tf-tmp/` and follow the naming scheme: `tf-tmp/<provider>/zone.tf`.

To generate a specific resource file:

```
bundle install
bundle exec rake generate
```

To show potential changes:

```
bundle exec rake plan
```

To apply the changes:

```
bundle exec rake apply
```
