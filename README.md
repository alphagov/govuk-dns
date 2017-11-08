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

[Install](#installation) Terraform 0.8 and `bundle install` the required Ruby gems.

Set up an [S3 bucket](https://aws.amazon.com/s3) to store the Terraform remote state. It is recommended that you keep it private and enable versioning and logging. You only need to do this once.

These tools use a YAML file format to store the zonefile. An existing BIND formatted zonefile can be imported using:

```bash
$ ZONEFILE=<path to file> bundle exec rake import_bind
```

Terraform resources can then be created in `tf-tmp` for your providers using:

```bash
$ ZONEFILE=zonefile.yaml PROVIDERS=<dns provider> bundle exec rake generate_terraform
```

Where `<dns provider>` is one of 'gce', 'route53' or 'all'.

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

## Installation ##

Install [Terraform 0.8](https://releases.hashicorp.com/terraform/) ([guide](https://www.terraform.io/downloads.html)). NOTE Terraform can be installed using brew but this is the incorrect version (0.9).

Install the Ruby gems:
```bash
$ gem install bundle
$ cd <path to this repo>
$ bundle install
```

## The Tasks ##

All tasks are defined and run using [Rake](https://ruby.github.io/rake/). They are split into two sets: those for managing DNS and those for testing.

They generally operate on a common [YAML zonefile format](#yaml-zonefile).

These should be run using:
```bash
$ bundle exec rake <task>
```

with required environment variables either being set by `export` or before the command e.g.:
```bash
$ PROVIDERS=all ZONEFILE=zonefile.yaml bundle exec rake generate_terraform
```

### Management ###

* [`import_bind`](#import-bind) Create a YAML formatted zonefile from an existing [BIND formatted zonefiles](https://en.wikipedia.org/wiki/Zone_file)
* [`generate_terraform`](#generate-terraform) Create Terraform records from an existing YAML zonefile.
* [ `tf:plan`, `tf:validate`, `tf:apply`, `tf:destroy`](#terraform) Wrappers to the Terraform commands using remote state.

### Testing ###

* [`rspec`](#rspec) Run the [RSpec](http://rspec.info/) unit tests (excludes the `validate_dns` tests)
* [`validate_dns`](#validate-dns) Compare a YAML zonefile against the "live" DNS state
* [`validate_yaml`](#validate-yaml) Check a YAML zonefile for basic formatting errors.

## Import BIND ##

This will produce a YAML formatted zonefile for use with other commands.

* `ZONEFILE` (required) - The BIND file to import
* `OUTPUTFILE` - Name of the file to create. Default: `zonefile.yaml`

for example:
```bash
$ ZONEFILE=zone.bind OUTPUTFILE=out.yaml bundle exec rake import_bind
```

## Generate Terraform ##

Given a YAML zonefile produce Terraform JSON for each specified provider. The produced Terraform is put in a directory called `tf-tmp/<provider>` 

* `ZONEFILE` (required) - The YAML formatted file to use
* `PROVIDERS` (required) - Which DNS providers to produce Terraform for

### Providers ###

* `all` - Special value, uses all available providers.
* `gce` - [Google's Cloud DNS](https://cloud.google.com/dns/docs/)
* `route53` - [AWS' Route53](https://aws.amazon.com/route53)

## Terraform ##

A set of wrappers for standard Terraform commands. These wrappers store state in S3 using Terraform's remote state files.

* `tf:plan` - Calculate what changes would be made
* `tf:validate` - Confirm that the terraform is valid (does not guarantee that it will work).
* `tf:apply` - Make the changes
* `tf:destroy` - Destroy the state.

### Shared environment variables ###

Other than `tf:validate` the Terraform tasks all share a number of options (`tf:validate` which only needs `PROVIDERS`).

* `PROVIDERS` (required) - see [above](#providers).
* `DEPLOY_ENV` (required) - where to deploy to, one of `production`, `staging` or `integration`.
* `AWS_ACCESS_KEY_ID` (required) - Access key with permissions for the bucket.
* `AWS_SECRET_ACCESS_KEY` (required) - Secret associated with the access key.
* `AWS_DEFAULT_REGION` - Which region the S3 bucket is in. Default: `eu-west-1`
* `BUCKET_NAME` - Name of the S3 bucket. Default: `dns-state-bucket-<environment>`, `environment` is set by DEPLOY_ENV.

### Google Cloud specific environment variables ###

Along with the environment variables set above, when deploying to Google the following must also be set:

* `GOOGLE_DNS_NAME` - The DNS domain that will be deployed to (e.g. `example.com.`, GCE needs fully qualified domain names for its entries).
* `GOOGLE_ZONE_NAME` - name of the hosted zone.
* `GOOGLE_PROJECT` - project ID
* `GOOGLE_REGION` - project region
* `GOOGLE_CREDENTIALS` - JSON credentials for the service account to deploy using (best set using `GOOGLE_CREDENTIALS=$(cat <path to credentials>`).

#### Route 53 ####

* `ROUTE53_ZONE_ID` - which zone to deploy to.

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
records:
- record_type: TXT
  subdomain: "@"
  ttl: '3600'
  data: 'v=spf1\ -all'
...
```

`record_type` should be one of:

* A 
* NS
* MX
* TXT
* CNAME

We only validate a subset of [RFC 1035](https://www.ietf.org/rfc/rfc1035.txt). If you do not see the record you wish to add in the following list it will not be considered valid and will need to be added.

### Data fields ###
This is a list of currently supported record types and the expected format of their data fields.

* **A**: of the form `a.a.a.a` where `a` is a number between 0 and 255 and may be zero padded. For example both `127.0.0.1` and `127.000.000.001` are both valid.
* **NS**: a fully qualified domain name (FQDN) containing only numbers, lower-case ASCII letters, hyphens and periods. The trailing period must be present, for example `example.com.` is valid while `example.com` is not.
* **MX**: a priority value followed by a FQDN (see NS record for details). For example `10 example.com.`
* **TXT**: any non-empty string. TXT fields should have all whitespace escaped (`\ `). If whitespace is intended to indicate multiple records then these should be added separately.
* **CNAME**: a FQDN (see NS record).

### Subdomain ###
For A, NS, MX, CNAME records it may either be:

* `@` to refer to the domain origin
* *or* a label formed of numbers, letters, hyphens and periods. For example `test-api` is valid, `test_api` is not.

TXT records follow the same rules but their labels may also contain underscores. For example both `@` and `_api_key` are valid TXT subdomains.

### TTL ###
Must be an integer value between 300s and 86400s (1 day).

## Rationale ##

This intended to be a brief explanation of how GOV.UK uses these tools.

The `import_bind` task is a one-shot tool for set-up. It's not intended for regular use and the YAML it produces should be checked. We used it to initialise our YAML as we had over 200 records to import when we set this up. This is also why we only support a sub-set of record types as these are the ones we currently use.

We keep the YAML in a separate repo that our developers can directly modify, this is part of the reason for choosing YAML as it is a more approachable format. The `validate_yaml` task is run on every PR against that repository to check for easy mistakes.

The `generate_terraform`, `tf:plan` and `tf:apply` tasks carry out the bulk of the work and are used whenever we want to deploy an update to our DNS. Using them in that order gives us confidence in which changes we will make before we make them.

The `validate_dns` task is run nightly as a check that the YAML file is an accurate representation of our DNS. It has a slight blindspot in that records added manually to the zone may not be detected as the task will not know which subdomain to query.

