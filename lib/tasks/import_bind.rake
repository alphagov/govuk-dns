# http://www.rubydoc.info/github/lantins/dns-zone/
require 'dns/zone'
require 'yaml'

require_relative './utilities/common'

desc "Generate YAML file from Zonefile"
task :import_bind do
  outputfile = ENV['OUTPUTFILE'] || 'zonefile.yaml'

  # Read zonefile
  contents = File.read(zonefile)

  # Generate zone object with zone file
  zone = DNS::Zone.load(contents)

  # Initialise a new hash to store zone information we want.
  zone_hash = {
    'origin' => zone.origin,
    'records' => [],
  }

  # Iterate each one of the records
  zone.records.each do |record|
    # Skip the SOA
    next if record.type == 'SOA'

    if record.label == zone.origin || record.label == "@"
      next if record.type == 'NS'
    end

    if record.label == zone.origin
      subdomain = '@'
    else
      subdomain = record.label
    end

    # Records inherit fields for a parent Record object, we explicitly read
    # the fields as we cannot extract them with the instance_variables method
    record_hash = {
      'record_type' => record.type,
      'subdomain' => subdomain,
      'ttl' => record.ttl,
    }

    case record.type
    when 'NS'
      record_hash['data'] = record.nameserver
    when 'TXT'
      text = record.text.gsub(' ', '\ ')
      warn "Space escaped in TXT record for #{record.label}." if text != record.text
      record_hash['data'] = "__single_quote__#{text}__single_quote__"
    when 'SPF'
      text = record.text.gsub(' ', '\ ')
      warn "Space escaped in SPF record for #{record.label}." if text != record.text
      record_hash['data'] = "__single_quote__#{text}__single_quote__"
    when 'A'
      record_hash['data'] = record.address
    when 'CNAME'
      record_hash['data'] = record.domainname
    when 'MX'
      record_hash['data'] = "#{record.priority} #{record.exchange}"
    else
      raise "Unknown record type: #{record.type}"
    end

    zone_hash['records'].push(record_hash)
  end

  yaml_string = zone_hash.to_yaml
  yaml_string.gsub!(/__single_quote__/, '\'')
  File.write(outputfile, yaml_string)
end
