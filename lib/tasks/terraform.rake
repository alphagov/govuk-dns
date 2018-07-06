require_relative './utilities/common'

namespace :tf do
  desc 'Validate the generated terraform'
  task :validate do
    _check_terraform_version
    providers.each { |current_provider|
      puts "Validating #{current_provider} terraform"
      _run_system_command("terraform validate #{TMP_DIR}/#{current_provider}")
    }
  end

  desc 'Apply the terraform resources'
  task :apply do
    _run_terraform_init
    _run_terraform_cmd_for_providers('apply')
  end

  desc 'Destroy the terraform resources'
  task :destroy do
    _run_terraform_cmd_for_providers('destroy')
  end

  desc 'Show the plan'
  task :plan do
    _run_terraform_init
    _run_terraform_cmd_for_providers('plan -module-depth=-1')
  end
end

def _run_terraform_init
  providers.each do |current_provider|
    _run_system_command("cd #{TMP_DIR}/#{current_provider} && terraform init -reconfigure -get=true")
  end
end

def _run_terraform_cmd_for_providers(command)
  _check_terraform_version
  _local_state_check
  _validate_terraform_environment
  _purge_remote_state

  puts command

  providers.each do |current_provider|
    puts "Running for #{current_provider}"

    puts "Using statefile: s3://#{bucket_name}/#{current_provider}/#{statefile_name}"

    terraform_cmd = []
    terraform_cmd << "cd #{TMP_DIR}/#{current_provider} &&"
    terraform_cmd << 'terraform'
    terraform_cmd << command

    _run_system_command(terraform_cmd.join(' '))
  end
end

def _local_state_check
  state_file = 'terraform.tfstate'

  if File.exist? state_file
    abort('Local state file should not exist. We use remote state files.')
  end
end

def _purge_remote_state
  state_file = '.terraform/terraform.tfstate'

  FileUtils.rm state_file if File.exist? state_file

  if File.exist? state_file
    abort("State file should not exist: #{state_file}")
  end
end

def _validate_terraform_environment
  allowed_envs = %w(test staging integration production)

  unless allowed_envs.include?(deploy_env)
    abort("Please set 'DEPLOY_ENV' environment variable to one of #{allowed_envs.join(', ')}")
  end

  ENV['AWS_DEFAULT_REGION'] = ENV['AWS_DEFAULT_REGION'] || region

  providers.each { |current_provider|
    required_vars = REQUIRED_ENV_VARS[current_provider.to_sym]
    required_vars[:env].each { |var|
      required_from_env(var)
    }
  }
end

def _check_terraform_version
  # Make sure that the version of Terraform we're using is new enough
  current_terraform_version = Gem::Version.new(`terraform version`.split("\n").first.split(' ')[1].delete('v'))
  minimum_terraform_version = Gem::Version.new(File.read('.terraform-version').strip)
  maximum_terraform_version = minimum_terraform_version.bump

  if current_terraform_version < minimum_terraform_version
    puts 'Terraform is not up to date enough.'
    puts "v#{current_terraform_version} installed, v#{minimum_terraform_version} required."
    exit 1
  elsif current_terraform_version > maximum_terraform_version
    puts 'Terraform is too new.'
    puts "We do not support terraform #{maximum_terraform_version} and above"
    exit 1
  end
end

def _run_system_command(command)
  if ENV['VERBOSE']
    puts command.to_s
  end

  abort("#{command} failed") unless system(command)
end
