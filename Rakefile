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

desc 'Configure the remote state. Destroys local only state.'
task configure_state: [:local_state_check, :configure_s3_state] do
  # This exists because in the default case we want to delete local state.
  #
  # In a bootstrap situation don't purge the local state otherwise we'll
  # never have anything to push to S3.
  true
end

desc 'Configure the remote state location'
task configure_s3_state: [:validate_environment, :purge_remote_state] do
  # workaround until we can move everything in to project based layout

  providers.each { |provider|
    args = []
    args << 'terraform remote config'
    args << '-backend=s3'
    args << '-backend-config="acl=private"'
    args << "-backend-config='bucket=#{bucket_name}'"
    args << '-backend-config="encrypt=true"'
    args << "-backend-config='key=#{provider}/terraform.tfstate'"
    args << "-backend-config='region=#{region}'"

    _run_system_command(args.join(' '))
  }
end

desc 'Apply the terraform resources'
task apply: [:configure_state] do
  puts "terraform apply #{TMP_DIR}"

  _run_system_command("terraform apply #{TMP_DIR}")
end

desc 'Destroy the terraform resources'
task destroy: [:configure_state] do
  puts "terraform destroy #{TMP_DIR}"

  _run_system_command("terraform destroy #{TMP_DIR}")
end

desc 'Show the plan'
task plan: [:configure_state] do
  _run_system_command("terraform plan -module-depth=-1 #{TMP_DIR}")
end

# FIXME: This errors on initial run, but does the correct thing, but needs to be run twice.
desc 'Bootstrap a project from local configuration to a clean bucket'
task :bootstrap do
  _run_system_command("terraform plan -module-depth=-1 #{TMP_DIR}")
  _run_system_command("terraform apply #{TMP_DIR}")

  Rake::Task['configure_s3_state'].invoke
end

desc "Clean the temporary directory"
task :clean do
  files = Dir["./#{TMP_DIR}/*.tf"]
  if ! files.empty?
    FileUtils.rm files
  end
end

desc 'Generate Terraform DNS configuration'
task generate: [:validate_generate_environment, :clean] do

  Dir.mkdir(TMP_DIR) unless File.exists?(TMP_DIR)
  records = YAML.load(File.read(ENV['ZONEFILE']))

  # Render all the expected files
  providers.each { |provider|
    renderer = ERB.new(File.read("templates/#{provider}.tf.erb"))
    File.write("#{TMP_DIR}/#{provider}.tf", renderer.result(binding))
  }
end

def _run_system_command(command)
  if dry_run
    command = "echo #{command}"
  end

  system(command)
  exit_code = $?.exitstatus

  if exit_code != 0
    raise "Running '#{command}' failed with code #{exit_code}"
  end
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
