require 'yaml'
require 'optparse'

require_relative './zone_file_field_validator'


desc "Validate a YAML Zone file"
task :validate_yaml do
  # Set default options and read command line arguments
  options = {
    zonefile: './zonefile.yaml',
    verbose: false
  }

  arg_parser = OptionParser.new { |opt|
    opt.banner = "Usage: rake validate_yaml [options]"
    opt.on('-f ZONEFILE', '--file ZONEFILE') { |file|
      options[:zonefile] = file
    }
    opt.on('-v', '--verbose') {
      options[:verbose] = true
    }
  }

  # return `ARGV` with the intended arguments
  args = arg_parser.order!(ARGV) {}
  arg_parser.parse!(args)

  # Read zonefile
  zone_data = YAML.load(File.read(options[:zonefile]))

  errors = ZoneFileFieldValidator.get_zone_errors(zone_data)

  if ! errors.empty?
    errors.each { |err| puts err }
    puts "\n#{errors.length} errors found."
    exit 1
  end

  puts "No errors found." if options[:verbose]
end
