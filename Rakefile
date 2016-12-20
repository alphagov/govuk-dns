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

  unless ENV.include?('TF_VAR_account_id')
    warn 'Please set the "TF_VAR_account_id" environment variable.'
    exit 1
  end
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

  args = []
  args << 'terraform remote config'
  args << '-backend=s3'
  args << '-backend-config="acl=private"'
  args << "-backend-config='bucket=#{bucket_name}'"
  args << '-backend-config="encrypt=true"'
  args << "-backend-config='key=terraform.tfstate'"
  args << "-backend-config='region=#{region}'"

  _run_system_command(args.join(' '))
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

desc 'Generate Terraform Route53 DNS configuration'
task :generate_route53 do
  Dir.mkdir(tmp_dir) unless File.exists?(tmp_dir)

  unless ENV.include?('ZONEFILE')
    warn 'Please set the "ZONEFILE" environment variable.'
    exit 1
  end

  unless ENV.include?('ROUTE53_ZONE_ID')
    warn 'Please set the "ROUTE53_ZONE_ID" environment variable.'
    exit 1
  end

  route53records = YAML.load(File.read(ENV['ZONEFILE']))
  renderer = ERB.new(File.read('templates/route53.tf.erb'))

  File.write("#{tmp_dir}/route53.tf", renderer.result(binding))
end

desc 'Generate Terraform Dyn DNS configuration'
task :generate_dyn do
  Dir.mkdir(tmp_dir) unless File.exists?(tmp_dir)

  unless ENV.include?('ZONEFILE')
    warn 'Please set the "ZONEFILE" environment variable.'
    exit 1
  end

  unless ENV.include?('DYN_ZONE_ID')
    warn 'Please set the "DYN_ZONE_ID" environment variable.'
    exit 1
  end

  dynrecords = YAML.load(File.read(ENV['ZONEFILE']))
  renderer = ERB.new(File.read('templates/dyn.tf.erb'))

  File.write("#{tmp_dir}/dyn.tf", renderer.result(binding))
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

def deploy_env
  ENV['DEPLOY_ENV']
end

def region
  ENV['REGION'] || 'eu-west-2'
end

def bucket_name
  ENV['BUCKET_NAME'] || 'govuk-terraform-dns-state-' + deploy_env
end

def dry_run
  ENV['DRY_RUN'] || true
end

def debug
  ENV['DEBUG']
end
