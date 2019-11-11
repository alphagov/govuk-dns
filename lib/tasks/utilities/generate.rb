require "digest"

def generate_terraform_object(statefile_name, region, deploy_env, provider, origin, records, deployment_config)
  case provider
  when "gcp"
    tf_provider = "google"
    resources = { google_dns_record_set: _get_gcp_resource(records, origin, deployment_config) }
  when "aws"
    tf_provider = provider
    resources = { aws_route53_record: _get_aws_resource(records, deployment_config) }
  end
  {
    terraform: {
      backend: {
        "s3": {
          encrypt: true,
          bucket: "dns-state-bucket-#{deploy_env}",
          key: "#{provider}/#{statefile_name}",
          region: region,
        },
      },
      required_version: "= 0.11.14",
    },
    provider: {
      "#{tf_provider}": {
        region: "eu-west-1",
        version: provider_version(tf_provider),
      }
    },
    resource: resources,
  }
end

def provider_version(tf_provider)
  case tf_provider
  when "google"
    "1.15.0"
  when "aws"
    "1.26.0"
  end
end

def _get_gcp_resource(records, origin, deployment_config)
  resource_hash = Hash.new

  grouped_records = records.group_by { |rec| [rec["subdomain"], rec["record_type"]] }

  grouped_records.each { |subdomain_and_type, record_set|
    subdomain, type = subdomain_and_type
    data = record_set.collect { |r| _split_line_gcp(r["data"]) }.flatten
    title = _get_resource_title(subdomain, data, type)

    record_name = subdomain == "@" ? origin : "#{subdomain}.#{origin}"

    resource_hash[title] = {
      managed_zone: deployment_config["zone_name"],
      name: record_name,
      type: type,
      ttl: record_set.collect { |r| r["ttl"] }.min,
      rrdatas: data,
    }
  }

  resource_hash
end

def _get_aws_resource(records, deployment_config)
  resource_hash = Hash.new

  grouped_records = records.group_by { |rec| [rec["subdomain"], rec["record_type"]] }

  grouped_records.each { |subdomain_and_type, record_set|
    subdomain, type = subdomain_and_type
    data = record_set.collect { |r| _split_line_aws(r["data"]) }.flatten
    title = _get_resource_title(subdomain, data, type)

    record_name = subdomain == "@" ? "" : subdomain.to_s

    resource_hash[title] = {
      zone_id: deployment_config["zone_id"],
      name: record_name,
      type: type,
      ttl: record_set.collect { |r| r["ttl"] }.min,
      records: data,
    }
  }

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
  data.gsub('\\', '\\\\\\')
end

def _get_resource_title(title, data_array, type)
  title = _get_tf_safe_title(title)
  record_md5 = _get_record_md5(title, data_array, type)
  "#{title}_#{record_md5}"
end

def _get_record_md5(title, data_array, type)
  data_string = data_array.sort.join(" ")

  md5 = Digest::MD5.new
  md5 << title
  md5 << data_string
  md5 << type
  md5.hexdigest
end

def _get_tf_safe_title(title)
  # Terraform resource records cannot contain '.'s or '@'s
  title.tr(".", "_").gsub(/@/, "AT").gsub("*", "WILDCARD")
end
