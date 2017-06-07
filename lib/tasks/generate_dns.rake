require 'fileutils'
require 'yaml'
require 'json'

desc 'Validate the environment for generating resources'
task :validate_generate_environment do
  if providers.nil?
    warn "Please set the 'PROVIDERS' environment variable to any of #{ALLOWED_PROVIDERS.join(', ')} or all."
    exit 1
  end

  _check_for_missing_var('ZONEFILE')
end

desc "Clean the temporary directory"
task :clean do
  files = Dir["./#{TMP_DIR}/*/*.tf"]
  files << Dir["./#{TMP_DIR}/*.tf"]
  if ! files.empty?
    FileUtils.rm files
  end
end
require_relative './utilities/common'
require_relative './utilities/generate'

desc 'Generate Terraform DNS configuration'
task generate_terraform: [:validate_generate_environment, :clean] do
  Dir.mkdir(TMP_DIR) unless File.exist?(TMP_DIR)
  records = YAML.load(File.read(ENV['ZONEFILE']))['records']

  # Render all the expected files
  providers.each { |current_provider|
    tf_vars = REQUIRED_ENV_VARS[current_provider.to_sym][:tf]
    out = _generate_terraform_object(current_provider, records, tf_vars)

    provider_dir = "#{TMP_DIR}/#{current_provider}"
    Dir.mkdir(provider_dir) unless File.exist?(provider_dir)
    # Use pretty_generate so the JSON is still vaguely human readable
    File.write("#{provider_dir}/zone.tf", JSON.pretty_generate(out))
  }
end
