require 'fileutils'
require 'yaml'
require 'json'

require_relative './utilities/common'
require_relative './utilities/generate'

desc 'Generate Terraform DNS configuration'
task :generate_terraform do
  Dir.mkdir(TMP_DIR) unless File.exist?(TMP_DIR)

  # Clean the tmp-dir
  files = Dir["./#{TMP_DIR}/*/*.tf"]
  files << Dir["./#{TMP_DIR}/*.tf"]
  if ! files.empty?
    FileUtils.rm files
  end

  # Load configuration
  config_file = YAML.load_file(zonefile)
  origin = config_file['origin']
  deployment = config_file['deployment']
  records = config_file['records']

  abort('Origin does not have trailing dot') unless origin.match?(/\.$/)

  # Render all the expected files
  providers.each { |current_provider|
    abort('Must set deployment options in configuration file') if deployment[current_provider].empty?

    deploy_vars = deployment[current_provider]

    out = generate_terraform_object(statefile_name, region, deploy_env, current_provider, origin, records, deploy_vars)

    provider_dir = "#{TMP_DIR}/#{current_provider}"
    Dir.mkdir(provider_dir) unless File.exist?(provider_dir)
    # Use pretty_generate so the JSON is still vaguely human readable
    File.write("#{provider_dir}/zone.tf", JSON.pretty_generate(out))
  }
end
