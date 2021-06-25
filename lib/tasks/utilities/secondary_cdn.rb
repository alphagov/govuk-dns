require 'json'
require 'shellwords'
require 'yaml'
require 'open3'

MAGENTA = "\e[35m"
CYAN = "\e[36m"
RESET = "\e[0m"

# TODO: use this structure
DISTRIBUTIONS = YAML.safe_load <<YAML
---
# TTLs are set to 300 (5 mins) during fail over to make switching back quick
environments:
- name: production
  providers:
  - aws
  - gcp
  records:
  - domain: "www-cdn.production.govuk.service.gov.uk."
    cloud_front_comment: "WWW"
    gcloud_zone_name: "govuk-service-gov-uk"
    ttl: 300 
  - domain: "assets.publishing.service.gov.uk."
    cloud_front_comment: "Assets"
    gcloud_zone_name: "publishing-service-gov-uk"
    ttl: 300
YAML

class Executor
    Result = Struct.new(:output, :success?)

    def run(*cmd)
        puts "$ #{cmd.shelljoin}"
        output, status = Open3.capture2e(*cmd)
        puts output unless status.success?
        Result.new(output.chomp, status.success?)
    rescue SystemCallError => e
        Result.new(e.message, false)
    end
end

class AwsCli
    def initialize(executor = nil)
        @executor = executor || Executor.new
    end

    def installed?
        @executor.run("aws", "--version").success?
    end

    def signed_in?
        @executor.run("aws", "sts", "get-caller-identity").success?
    end

    def get_cnames
        distributions = [{
            domain: 'www-cdn.production.govuk.service.gov.uk',
            comment: 'WWW',
        }, {
            domain: 'assets.publishing.service.gov.uk',
            comment: 'Assets',
        }]
        cnames = distributions.to_h do |distribution|
            comment = distribution[:comment]
            domain = distribution[:domain]
            result = @executor.run("aws", "cloudfront", "list-distributions", "--query", "DistributionList.Items[?Comment=='#{comment}'].DomainName | [0]", "--output", "text")
            raise "Failed to find cloudfront distribution for #{comment}\n\n#{output}" unless result.success?
            [domain, result.output]
        end
        cnames
    end

    def update_dns!(domain, cname)
        result = @executor.run("aws", "route53", "list-hosted-zones-by-name", "--dns-name", domain, "--max-items", "1", "--query", "HostedZones[?Name==`#{domain}`] | [0].Id", "--output", "text")
        raise "could not get hosted zone ID for domain #{domain}" unless result.success?
        raw_zone_id = result.output
        raise "raw_zone_id in unexpected format. Expected /^\/hostedzone\/[[:alnum:]]+$/ got #{raw_zone_id}" unless raw_zone_id =~ /^\/hostedzone\/[[:alnum:]]+$/
        zone_id = raw_zone_id.sub("/hostedzone/", "")

        json_change_batch = JSON.dump({
            "Comment" => "Fail over to secondary CDN using govuk-dns / rake fall_back_to_secondary_cdn",
            "Changes" => [
                {
                    "Action" => "UPSERT",
                    "ResourceRecordSet" => {
                        "Name" => domain,
                        "Type" => "CNAME",
                        "TTL" => 300,
                        "ResourceRecords" => [
                            {
                                "Value" => cname
                            }
                        ]
                    }
                }
            ]
        })

        # Aiming for:
        # aws route53 change-resource-record-sets --hosted-zone-id #{zone_id} --change-batch #{json_change_batch}
    end
end

class GcloudCli
    def initialize(executor = nil)
        @executor = executor || Executor.new
    end

    def installed?
        @executor.run("gcloud", "--version").success?
    end

    def signed_in?
        @executor.run("gcloud", "auth", "print-access-token").success?
    end

    def target_is_production?
        result = @executor.run("gcloud", "config", "get-value", "project")
        raise "Failed to get current gcloud project\n\n#{result.output}" unless result.success?
        if result.output == "govuk-production"
            true
        else
            puts result.output
            false
        end
    end

    def update_dns!(domain, cname)
        puts([
            "gcloud", "dns", "record-sets", "update",
            domain,
            "--rrdatas=#{cname}",
            "--ttl=300",
            "--type=CNAME",
            "--zone=MANAGED_ZONE", # TODO
        ].join(" "))
    end
end

class GcloudCliFallback
    def installed?
        true
    end

    def signed_in?
        true
    end

    def target_is_production?
        true
    end
end

class SecondaryCDN
    def initialize()
        @aws_cli = AwsCli.new()
        @gcloud_cli = GcloudCli.new()
    end

    def fall_back!
        abort("this task requires the aws CLI to be installed") unless @aws_cli.installed?
        unless @gcloud_cli.installed?
            # If the user doesn't have gcloud installed, we can still walk them through
            # the steps to do the fail over manually in the GCloud UI.
            puts("Clouldn't find the gcloud CLI. Falling back to manual instructions for GCP.")
            @gcloud_cli = GcloudCliFallback.new()
        end

        unless @aws_cli.signed_in?
            abort <<~EOF
            No credentials for AWS found.
            
            Please run the task again providing AWS credentials (e.g. using gds aws govuk-production-poweruser -- rake fall_back_to_secondary_cdn)
            EOF
        end

        unless @gcloud_cli.signed_in?
            abort <<~EOF
            No credentials for GCP found.
            
            Please run the task again after signing in to GCP (gcloud auth login)
            EOF
        end

        unless @gcloud_cli.target_is_production?
            abort <<~EOF
            gcloud is not set to target the govuk-production project.
            
            Please run the task again after targetting govuk-production (gcloud config set project govuk-production)
            EOF
        end

        cnames = @aws_cli.get_cnames
        confirm_changes(cnames)

        cnames.each do |domain, cname|
            @gcloud_cli.update_dns! domain, cname
            @aws_cli.update_dns!    domain, cname
        end
    end

    def confirm_changes(cnames)
        puts "\n#{CYAN}The following #{cnames.length * 2} DNS changes need to be made:#{RESET}\n\n"
        cnames.each do |domain, cname|
            puts "* [ ] Change the CNAME on #{domain} to #{cname} in AWS"
            puts "* [ ] Change the CNAME on #{domain} to #{cname} in GCP"
        end
        puts "\n#{MAGENTA}Do you want to make these changes now? Yes / No #{RESET}\n\n"
        puts "⚠️ THIS WILL ROUTE PRODUCTION TRAFFIC TO THE SECONDARY CDN ⚠️"
        $stdout.printf "\n> "

        while answer = $stdin.gets.chomp do
            case answer
            when "Yes"
                break
            when "No"
                exit
            else
                $stdout.printf "Please enter exactly Yes or No\n\n> "
            end
        end
    end
end
