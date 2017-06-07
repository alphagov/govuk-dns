require 'dns/zone'
require 'optparse'
require 'yaml'

task default: [:generate_yaml]

desc "Generate YAML file from Zonefile"
task :generate_yaml do
  # Set default options and read command line arguments
  options = {
    zonefile: './zonefile',
    outputfile:  './zonefile.yaml',
    verbose: false
  }

  arg_parser = OptionParser.new { |opt|
    opt.banner = "Usage: rake generate_yaml [options]"
    opt.on('-f ZONEFILE', '--file ZONEFILE') { |file|
      options[:zonefile] = file
    }
    opt.on('-o OUTPUTFILE', '--output OUTPUTFILE') { |file|
      options[:outputfile] = file
    }
    opt.on('-v', '--verbose') {
      options[:verbose] = true
    }
  }

  # return `ARGV` with the intended arguments
  args = arg_parser.order!(ARGV) {}
  arg_parser.parse!(args)

  # Read zonefile
  contents = File.read(options[:zonefile])

  # Generate zone object with zone file
  zone = DNS::Zone.load(contents)

  # Initialise a new hash to store zone information with the fields of the zone and record objects,
  # so it outputs the information that we want. For more information, review the dns-zone documentation:
  # http://www.rubydoc.info/github/lantins/dns-zone/
  zone_hash = Hash.new
  zone_hash['origin'] = zone.origin
  zone_hash['records'] = []

  # Iterate each one of the records
  zone.records.each do |record|
    # Skip the SOA
    next if record.type == 'SOA'

    # Records inherit fields for a parent Record object, we explicitly read the fields as we cannot extract them
    # with the instance_variables method
    record_hash = Hash.new
    record_hash['record_type'] = record.type
    record_hash['subdomain'] = record.label
    record_hash['ttl'] = record.ttl

    case record.type
    when 'NS'
      record_hash['data'] = record.nameserver
    when 'TXT'
      record_hash['data'] = record.text
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

  File.write(options[:outputfile], zone_hash.to_yaml)

  if options[:verbose]
    $stdout.puts zone_hash.to_yaml
  end
end
