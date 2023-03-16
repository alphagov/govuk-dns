require "digest"

def generate_terraform_object(statefile_name, region, deploy_env, provider, origin, records, deployment_config)
  case provider
  when "gcp"
    tf_provider = "google"
    tf_provider_source = "hashicorp/google"

    resources = { google_dns_record_set: _get_gcp_resource(records, origin, deployment_config) }
  when "aws"
    tf_provider = "aws"
    tf_provider_source = "hashicorp/aws"

    resources = { aws_route53_record: _get_aws_resource(records, deployment_config) }
  end
  {
    terraform: {
      backend: {
        "s3": {
          encrypt: true,
          bucket: "dns-state-bucket-#{deploy_env}",
          key: "#{provider}/#{statefile_name}",
          region:,
        },
      },
      required_version: "= 1.4.1",
      required_providers: {
        "#{tf_provider}": {
          version: provider_version(tf_provider),
          source: tf_provider_source,
        },
      },
    },
    provider: {
      "#{tf_provider}": {
        region: "eu-west-1",
      },
    },
    resource: resources,
  }
end

def provider_version(tf_provider)
  case tf_provider
  when "google"
    "4.57.0"
  when "aws"
    "4.58.0"
  end
end

def _get_gcp_resource(records, origin, deployment_config)
  resource_hash = {}

  grouped_records = records.group_by { |rec| [rec["subdomain"], rec["record_type"]] }

  grouped_records.each do |subdomain_and_type, record_set|
    subdomain, type = subdomain_and_type
    data = record_set.collect { |r| _split_line_gcp(r["data"]) }.flatten
    title = _get_resource_title subdomain, type

    record_name = subdomain == "@" ? origin : "#{subdomain}.#{origin}"

    resource_hash[title] = {
      managed_zone: deployment_config["zone_name"],
      name: record_name,
      type:,
      ttl: record_set.collect { |r| r["ttl"] }.min,
      rrdatas: data,
    }
  end

  resource_hash
end

def _get_aws_resource(records, deployment_config)
  resource_hash = {}

  grouped_records = records.group_by { |rec| [rec["subdomain"], rec["record_type"]] }

  grouped_records.each do |subdomain_and_type, record_set|
    subdomain, type = subdomain_and_type
    data = record_set.collect { |r| _split_line_aws(r["data"]) }.flatten
    title = _get_resource_title subdomain, type

    record_name = subdomain == "@" ? "" : subdomain.to_s

    resource_hash[title] = {
      zone_id: deployment_config["zone_id"],
      name: record_name,
      type:,
      ttl: record_set.collect { |r| r["ttl"] }.min,
      records: data,
    }
  end

  resource_hash
end

def _split_line_gcp(data)
  if data.include?("v=DMARC1") && (data.length > 254)
    data1 = data.delete(" ")
    data1.split(";").join("; ").split(",").join(", ")
  else
    data.scan(/.{1,255}/).join(" ")
  end
end

def _split_line_aws(data)
  if data.include?("v=DMARC1") && (data.length > 254)
    data1 = data.delete(" ")
    data1.split(";").join(';""').split(",").join(',""')
  else
    data.scan(/.{1,255}/).join('""')
  end
end

def _get_tf_safe_data(data)
  # Terraform requires escaped slashes in its strings.
  # The 6 '\'s are required because of how gsub works (see https://www.ruby-forum.com/topic/143645)
  data.gsub("\\", "\\\\\\")
end

def _get_resource_title(title, type)
  _get_tf_safe_title "#{type}_#{title}"
end

def _get_tf_safe_title(title)
  # Terraform resource records cannot contain '.'s or '@'s
  title.tr(".", "_").gsub(/@/, "AT").gsub("*", "WILDCARD")
end
