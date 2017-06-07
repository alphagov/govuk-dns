require 'digest'

def _generate_terraform_object(provider, records, vars)
  case provider
  when 'gce'
    resources = { google_dns_record_set: _get_gce_resource(records) }
  when 'route53'
    resources = { aws_route53_record: _get_route53_resource(records) }
  when 'dyn'
    resources = { dyn_record: _get_dyn_resource(records) }
  end
  {
    variable: _get_tf_variables(vars),
    resource: resources,
  }
end

def _get_gce_resource(records)
  resource_hash = Hash.new

  grouped_records = records.group_by { |rec| [rec['subdomain'], rec['record_type']] }

  grouped_records.each { |subdomain_and_type, record_set|
    subdomain, type = subdomain_and_type
    data = record_set.collect { |r| r['data'] }.sort
    title = _get_resource_title(subdomain, data, type)

    record_name = subdomain == '@' ? "${var.GOOGLE_DNS_NAME}" : "#{subdomain}.${var.GOOGLE_DNS_NAME}"

    resource_hash[title] = {
      managed_zone: '${var.GOOGLE_ZONE_NAME}',
      name: record_name,
      type: type,
      ttl: record_set.collect { |r| r['ttl'] }.min,
      rrdatas: data,
    }
  }

  resource_hash
end

def _get_route53_resource(records)
  resource_hash = Hash.new

  grouped_records = records.group_by { |rec| [rec['subdomain'], rec['record_type']] }

  grouped_records.each { |subdomain_and_type, record_set|
    subdomain, type = subdomain_and_type
    data = record_set.collect { |r| r['data'] }.sort
    title = _get_resource_title(subdomain, data, type)

    record_name = subdomain == '@' ? "" : subdomain.to_s

    resource_hash[title] = {
      zone_id: '${var.ROUTE53_ZONE_ID}',
      name: record_name,
      type: type,
      ttl: record_set.collect { |r| r['ttl'] }.min,
      records: data,
    }
  }

  resource_hash
end

def _get_dyn_resource(records)
  resource_hash = Hash.new

  records.map { |rec|
    title = _get_resource_title(rec['subdomain'], [rec['data']], rec['record_type'])
    resource_hash[title] = {
      zone: '${var.DYN_ZONE_ID}',
      name: rec['subdomain'],
      type: rec['record_type'],
      ttl: rec['ttl'],
      value: rec['data'],
    }
  }

  resource_hash
end

def _get_tf_variables(provider_variables)
  # Produce a hash with keys set to the variables passed in
  Hash[provider_variables.map { |var| [var, {}] }]
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
  data_string = data_array.sort.join(' ')

  md5 = Digest::MD5.new
  md5 << title
  md5 << data_string
  md5 << type
  md5.hexdigest
end

def _get_tf_safe_title(title)
  # Terraform resource records cannot contain '.'s or '@'s
  title.tr('.', '_').gsub(/@/, 'AT')
end
