require "yaml"
require "optparse"

require_relative "./utilities/common"
require_relative "./utilities/zone_file_field_validator"

desc "Validate a YAML Zone file"
task :validate_yaml do
  zone_data = YAML.load_file(zonefile)

  errors = ZoneFileFieldValidator.get_zone_errors(zone_data)

  if !errors.empty?
    errors.each { |err| puts err }
    puts "\n#{errors.length} errors found."
    exit 1
  end

  puts "No errors found." if ENV["VERBOSE"]
end

desc "Validate all YAML files in a given directory"
task :validate_all_yaml do
  dir = ENV["VALIDATE_DIR_YAML"]

  abort("Must set VALIDATE_DIR_YAML environment variable.") unless dir

  files = Dir["#{dir}/*.yaml"]

  abort("No YAML files found in #{dir}.") if files.empty?

  files.each do |file|
    puts "Testing #{file}"
    zone_data = YAML.load_file(file)
    errors = ZoneFileFieldValidator.get_zone_errors(zone_data)

    if !errors.empty?
      errors.each { |err| puts err }
      puts "\n#{errors.length} errors found in #{file}."
      exit 1
    end

    puts "No errors found." if ENV["VERBOSE"]
  end
end
