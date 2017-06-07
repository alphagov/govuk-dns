require_relative './utilities/common'

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
  puts 'We do not support terraform #{maximum_terraform_version} and above'
  exit 1
end

namespace :tf do
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

  desc 'Validate the environment name'
  task :validate_terraform_environment do
    allowed_envs = %w(test staging integration production)

    _check_for_missing_var('DEPLOY_ENV')
    unless allowed_envs.include?(ENV['DEPLOY_ENV'])
      warn "Please set 'DEPLOY_ENV' environment variable to one of #{allowed_envs.join(', ')}"
      exit 1
    end

    ENV['AWS_DEFAULT_REGION'] = ENV['AWS_DEFAULT_REGION'] || region

    providers.each { |current_provider|
      required_vars = REQUIRED_ENV_VARS[current_provider.to_sym]
      required_vars[:tf].each { |var|
        _check_for_missing_var(var)
        # Set the terraform variable
        ENV["TF_VAR_#{var}"] = ENV[var]
      }

      required_vars[:env].each { |var|
        _check_for_missing_var(var)
      }
    }
  end

  desc 'Validate the generated terraform'
  task :validate do
    providers.each { |current_provider|
      puts "Validating #{current_provider} terraform"
      _run_system_command("terraform validate #{TMP_DIR}/#{current_provider}")
    }
  end

  desc 'Apply the terraform resources'
  task apply: [:local_state_check, :validate_terraform_environment, :purge_remote_state] do
    _run_terraform_cmd_for_providers('apply')
  end

  desc 'Destroy the terraform resources'
  task destroy: [:local_state_check, :validate_terraform_environment, :purge_remote_state] do
    _run_terraform_cmd_for_providers('destroy')
  end

  desc 'Show the plan'
  task plan: [:local_state_check, :validate_terraform_environment, :purge_remote_state] do
    _run_terraform_cmd_for_providers('plan -module-depth=-1')
  end
end

def _run_terraform_cmd_for_providers(command)
  puts command

  providers.each { |current_provider|
    puts "Running for #{current_provider}"

    # Configure terraform to use the correct remote state file
    configure_state_cmd = []
    configure_state_cmd << 'terraform remote config'
    configure_state_cmd << '-backend=s3'
    configure_state_cmd << '-backend-config="acl=private"'
    configure_state_cmd << "-backend-config='bucket=#{bucket_name}'"
    configure_state_cmd << '-backend-config="encrypt=true"'
    configure_state_cmd << "-backend-config='key=#{current_provider}/#{statefile_name}'"
    configure_state_cmd << "-backend-config='region=#{region}'"

    _run_system_command(configure_state_cmd.join(' '))

    terraform_cmd = []
    terraform_cmd << 'terraform'
    terraform_cmd << command
    terraform_cmd << "#{TMP_DIR}/#{current_provider}"

    _run_system_command(terraform_cmd.join(' '))
  }
end
