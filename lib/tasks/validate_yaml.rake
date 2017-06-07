require 'yaml'
require 'optparse'

require_relative './utilities/common'
require_relative './utilities/zone_file_field_validator'


desc "Validate a YAML Zone file"
task :validate_yaml do
  zone_data = YAML.load(File.read(zonefile))

  errors = ZoneFileFieldValidator.get_zone_errors(zone_data)

  if ! errors.empty?
    errors.each { |err| puts err }
    puts "\n#{errors.length} errors found."
    exit 1
  end

  puts "No errors found." if ENV['VERBOSE']
end
