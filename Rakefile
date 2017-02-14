require 'fileutils'
require 'rspec/core/rake_task'
require 'tmpdir'
require 'aws-sdk-resources'
require 'erb'
require 'yaml'

# Make sure that the version of Terraform we're using is new enough
current_terraform_version = Gem::Version.new(`terraform version`.split("\n").first.split(' ')[1].gsub('v', ''))
minimum_terraform_version = Gem::Version.new(File.read('.terraform-version').strip)
maximum_terraform_version = minimum_terraform_version.bump

if current_terraform_version < minimum_terraform_version
  puts 'Terraform is not up to date enough.'
  puts "v#{current_terraform_version} installed, v#{minimum_terraform_version} required."
  exit 1
elsif current_terraform_version > maximum_terraform_version
  puts 'Terraform is too new.'
  puts 'We do not support terraform #{maximum_terraform_version} and above'
  exit 1
end

desc 'Validate the environment name'
task :validate_environment do
  allowed_envs = %w(test staging integration production)

  unless ENV.include?('DEPLOY_ENV') && allowed_envs.include?(ENV['DEPLOY_ENV'])
    warn "Please set 'DEPLOY_ENV' environment variable to one of #{allowed_envs.join(', ')}"
    exit 1
  end
end

desc 'Validate the environment for generating resources'
task :validate_generate_environment do
  required_env_vars = {
    dyn: ['DYN_ZONE_ID', 'DYN_CUSTOMER_NAME', 'DYN_PASSWORD', 'DYN_USERNAME'],
    route53: ['ROUTE53_ZONE_ID', 'AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY'],
  }
  if providers().nil?
    warn "Please set the 'PROVIDERS' environment variable to any of #{ALLOWED_PROVIDERS.join(', ')} or all."
    exit 1
  end

  unless ENV.include?('ZONEFILE')
    warn 'Please set the "ZONEFILE" environment variable.'
    exit 1
  end

  # First check that we have all the zone names we expect
  providers().each { |provider|
    unless ALLOWED_PROVIDERS.include?(provider)
      warn "Unknown provider, '#{provider}', please use one of #{ALLOWED_PROVIDERS.join(', ')} or all."
      exit 1
    end

    required_env_vars[provider.to_sym].each { |var|
      unless ENV.include?(var)
        warn "Please set the '#{var}' environment variable."
        exit 1
      end
    }
  }
end

desc 'Check for a local statefile'
task :local_state_check do
  state_file = 'terraform.tfstate'

  if File.exist? state_file
    warn 'Local state file should not exist. We use remote state files.'
    exit 1
  end
end

desc 'Purge remote state file'
task :purge_remote_state do
  state_file = '.terraform/terraform.tfstate'

  FileUtils.rm state_file if File.exist? state_file

  if File.exist? state_file
    warn 'state file should not exist.'
    exit 1
  end
end

desc 'Apply the terraform resources'
task apply: [:local_state_check, :validate_environment, :purge_remote_state] do
  _run_terraform_cmd_for_providers("apply")
end

desc 'Destroy the terraform resources'
task destroy: [:local_state_check, :validate_environment, :purge_remote_state] do
  _run_terraform_cmd_for_providers("destroy")
end

desc 'Show the plan'
task plan: [:local_state_check, :validate_environment, :purge_remote_state] do
  _run_terraform_cmd_for_providers("plan -module-depth=-1")
end

desc "Clean the temporary directory"
task :clean do
  files = Dir["./#{TMP_DIR}/*/*.tf"]
  files << Dir["./#{TMP_DIR}/*.tf"]
  if ! files.empty?
    FileUtils.rm files
  end
end

desc 'Generate Terraform DNS configuration'
task generate: [:validate_generate_environment, :clean] do

  Dir.mkdir(TMP_DIR) unless File.exists?(TMP_DIR)
  records = YAML.load(File.read(ENV['ZONEFILE']))

  # Render all the expected files
  providers.each { |current_provider|
    renderer = ERB.new(File.read("templates/#{current_provider}.tf.erb"))
    provider_dir = "#{TMP_DIR}/#{current_provider}"
    Dir.mkdir(provider_dir) unless File.exists?(provider_dir)
    File.write("#{provider_dir}/zone.tf", renderer.result(binding))
  }
end

def _run_system_command(command)
  if dry_run == true
    command = "echo #{command}"
  end

  system(command)
  exit_code = $?.exitstatus

  if exit_code != 0
    raise "Running '#{command}' failed with code #{exit_code}"
  end
end

def _run_terraform_cmd_for_providers(command)
  puts "#{command}"

  providers.each { |current_provider|
    puts "Running for #{current_provider}"

    # Configure terraform to use the correct remote state file
    configure_state_cmd = []
    configure_state_cmd << 'terraform remote config'
    configure_state_cmd << '-backend=s3'
    configure_state_cmd << '-backend-config="acl=private"'
    configure_state_cmd << "-backend-config='bucket=#{bucket_name}'"
    configure_state_cmd << '-backend-config="encrypt=true"'
    configure_state_cmd << "-backend-config='key=#{current_provider}/terraform.tfstate'"
    configure_state_cmd << "-backend-config='region=#{region}'"

    _run_system_command(configure_state_cmd.join(' '))

    terraform_cmd = []
    terraform_cmd << 'terraform'
    terraform_cmd << command
    terraform_cmd << "#{TMP_DIR}/#{current_provider}"

    _run_system_command(terraform_cmd.join(' '))
  }
end

TMP_DIR = 'tf-tmp'
ALLOWED_PROVIDERS = ['dyn', 'route53']

def deploy_env
  ENV['DEPLOY_ENV']
end

def region
  ENV['REGION'] || 'eu-west-1'
end

def bucket_name
  ENV['BUCKET_NAME'] || 'dns-state-bucket-' + deploy_env
end

def dry_run
  ENV['DRY_RUN'] || true
end

def providers
  if ENV['PROVIDERS'] == 'all'
    return ALLOWED_PROVIDERS
  end

  if not ENV['PROVIDERS'].nil?
    return [ENV['PROVIDERS']]
  end

  raise 'Could not figure out which providers to deploy to.'
end
