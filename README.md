# GOV.UK DNS #

A set of rake tasks for managing DNS records using [Terraform](https://terraform.io).

| Table of Contents |
| ----------------- |
| [Quick Start](#quick-start) |
| [Installation](#installation) |
| [The Tasks](#the-tasks) |
| [Import BIND](#import-bind) |
| [Generate Terraform](#generate-terraform) |
| [Terraform](#terraform) |
| [Testing](#testing) |
| [YAML Zonefile](#yaml-zonefile) |
| [Rationale](#rationale) |

## Quick Start ##

Clone the repo, then:

```shell
$ brew install tfenv
$ tfenv install
$ bundle install
```

Set up an [S3 bucket](https://aws.amazon.com/s3) to store the Terraform remote state. It is recommended that you keep it private and enable versioning and logging. You only need to do this once.

Terraform resources can be created in `tf-tmp` for your providers using:

```bash
$ ZONEFILE=zonefile.yaml PROVIDERS=<dns provider> bundle exec rake generate_terraform
```

Where `<dns provider>` is either 'gcp' or 'aws'.

This terraform can then be planned and applied using:
```bash
$ export PROVIDERS=<provider>
$ export DEPLOY_ENV=<production, staging or integration>
$ export AWS_ACCESS_KEY_ID=<some secret>
$ export AWS_SECRET_ACCESS_KEY=<some secret>
$ bundle exec rake tf:plan
...
$ bundle exec rake tf:apply
...
```

**It is strongly recommended you always run `tf:plan` before `tf:apply`**

Some of these environment variables are provider specific. It is important to note that the AWS key and secret are required regardless as these are used to store the remote state. Please check [this section](#per-provider-environment-variables) for the specific variables your provider needs.

In addition to these core tools there are several more that we use regularly:
```bash
ZONEFILE=zonefile.yaml bundle exec rake validate_dns
```

This will run a series of checks to confirm that the contents of `zonefile.yaml` correctly represent what is currently visible online. We run it nightly to check that we are up-to-date.

```bash
ZONEFILE=zonefile.yaml bundle exec rake validate_yaml
```
We recommend that our developers directly edit our zonefile and submit PRs against the repo that contains it. We then use a hook to run these validation checks which ensure that common mistakes are avoided (for example fully qualified domain names must have a trailing `.`).

## The Tasks ##

All tasks are defined and run using [Rake](https://ruby.github.io/rake/). They are split into two sets: those for managing DNS and those for testing.

They generally operate on a common [YAML zonefile format](#yaml-zonefile).

These should be run using:

```bash
$ bundle exec rake <task>
```

with required environment variables either being set by `export` or before the command e.g.:
```bash
$ PROVIDERS=aws ZONEFILE=zonefile.yaml bundle exec rake generate_terraform
```

### Management ###

* [`generate_terraform`](#generate-terraform) Create Terraform records from an existing YAML zonefile.
* [ `tf:plan`, `tf:validate`, `tf:apply`, `tf:destroy`](#terraform) Wrappers to the Terraform commands using remote state.

### Testing ###

* [`rspec`](#rspec) Run the [RSpec](http://rspec.info/) unit tests (excludes the `validate_dns` tests)
* [`validate_dns`](#validate-dns) Compare a YAML zonefile against the "live" DNS state
* [`validate_yaml`](#validate-yaml) Check a YAML zonefile for basic formatting errors.

## Generate Terraform ##

Given a YAML zonefile produce Terraform JSON for each specified provider. The produced Terraform is put in a directory called `tf-tmp/<provider>`

* `ZONEFILE` (required) - The YAML formatted file to use
* `PROVIDERS` (required) - Which DNS providers to produce Terraform for

### Providers ###

* `gcp` - [Google Cloud DNS](https://cloud.google.com/dns/docs/)
* `aws` - [AWS Route 53](https://aws.amazon.com/aws)

## Terraform ##

A set of wrappers for standard Terraform commands. These wrappers store state in S3 using Terraform's remote state files.

* `tf:plan` - Calculate what changes would be made
* `tf:validate` - Confirm that the terraform is valid (does not guarantee that it will work).
* `tf:apply` - Make the changes
* `tf:destroy` - Destroy the state.

### Shared environment variables ###

Other than `tf:validate` the Terraform tasks all share a number of options (`tf:validate` which only needs `PROVIDERS`).

We use S3 as a backend for Terraform state, so AWS credentials are always required even when deploying to Google Cloud.

* `PROVIDERS` (required) - see [above](#providers).
* `DEPLOY_ENV` (required) - where to deploy to, one of `production`, `staging` or `integration`.
* `AWS_ACCESS_KEY_ID` (required) - Access key with permissions for the bucket.
* `AWS_SECRET_ACCESS_KEY` (required) - Secret associated with the access key.
* `AWS_DEFAULT_REGION` - Which region the S3 bucket is in. Default: `eu-west-1`
* `BUCKET_NAME` - Name of the S3 bucket. Default: `dns-state-bucket-<environment>`, `environment` is set by DEPLOY_ENV.

### Google Cloud specific environment variables ###

Along with the environment variables set above, when deploying to Google the following must also be set:

* `GOOGLE_PROJECT` - project ID
* `GOOGLE_REGION` - project region
* `GOOGLE_OAUTH_ACCESS_TOKEN` - a GCP access token (use `GOOGLE_OAUTH_ACCESS_TOKEN=$(gcloud auth print-access-token)`).

## Testing ##

Several tools are provided for testing purposes.

### RSpec ###

This runs the suite of tests specs defined in `spec/` against the rake tasks.

### Validate DNS ###

This iterates through the contents of a YAML zonefile and queries the DNS to check the current live results. It uses RSpec to specify the tests and produce a readable output but it is not included in the `rspec` task.

If you run the rspec tests without using the rake task you will need to either filter out this test (using `--tag ~validate_dns`) or make sure `ZONEFILE` is set.

* `ZONEFILE` (required) - the YAML zonefile to validate against the DNS
* `CUSTOM_NS` - a specific nameserver to query (useful for testing).

### Validate YAML ###

Check that a YAML file contains valid records.

* `ZONEFILE` (required) - the file to check
* `VERBOSE` - if set this will print a message if no errors are found.

## YAML Zonefile ##

The YAML Zonefile has the following format:

```yaml
origin: example.com.

deployment:
  gcp:
    zone_name: 'example-com'
  aws:
    zone_id: 'SOMEROUTE53ZONEID'

records:
- record_type: TXT
  subdomain: "@"
  ttl: '3600'
  data: 'v=spf1\ -all'
...
```

### Origin

The root name of the zone. This allows upstream validation of the deployed DNS.

### Deployment

This sets the options required for deployment. These details may be sensitive, so be aware
when setting them in the file. These details are used by Terraform to make changes to the
correct upstream hosted zone.

### Records

`record_type` should be one of:

* A
* AAAA
* NS
* MX
* TXT
* CNAME

We only validate a subset of [RFC 1035](https://www.ietf.org/rfc/rfc1035.txt). If you do not see the record you wish to add in the following list it will not be considered valid and will need to be added.

### Data fields ###

This is a list of currently supported record types and the expected format of their data fields.

* **A**: of the form `a.a.a.a` where `a` is a number between 0 and 255 and may be zero padded. For example both `127.0.0.1` and `127.000.000.001` are both valid.
* **AAAA**: of the form `a:a:a:a:a:a:a:a` where `a` is a 16-bit hex value (between `0000` and `ffff`). Leading zeroes may be omitted, and a single run of zero field values can be compressed to `::`. For example, `ff06:00c4:0000:0000:0000:0000:0000:00c3`, `ff06:c4:0:0:0:0:0:c3`, and `ff06:c4::c3` are all valid representations of the same address.
* **NS**: a fully qualified domain name (FQDN) containing only numbers, lower-case ASCII letters, hyphens and periods. The trailing period must be present, for example `example.com.` is valid while `example.com` is not.
* **MX**: a priority value followed by a FQDN (see NS record for details). For example `10 example.com.`
* **TXT**: any non-empty string. TXT fields should have all whitespace escaped (`\ `). If whitespace is intended to indicate multiple records then these should be added separately.
* **CNAME**: a FQDN (see NS record).

### Subdomain ###

For A, AAAA, NS, MX, CNAME records it may either be:

* `@` to refer to the domain origin
* *or* a label formed of numbers, letters, hyphens and periods. For example `test-api` is valid, `test_api` is not.

TXT records follow the same rules but their labels may also contain underscores. For example both `@` and `_api_key` are valid TXT subdomains.

### TTL ###

Must be an integer value between 300s and 86400s (1 day).

## Rationale ##

This intended to be a brief explanation of how GOV.UK uses these tools.

We keep the YAML in a separate repo that our developers can directly modify, this is part of the reason for choosing YAML as it is a more approachable format. The `validate_yaml` task is run on every PR against that repository to check for easy mistakes.

The `generate_terraform`, `tf:plan` and `tf:apply` tasks carry out the bulk of the work and are used whenever we want to deploy an update to our DNS. Using them in that order gives us confidence in which changes we will make before we make them.

The `validate_dns` task is run nightly as a check that the YAML file is an accurate representation of our DNS. It has a slight blindspot in that records added manually to the zone may not be detected as the task will not know which subdomain to query.

## Licence

[MIT License](LICENCE)

