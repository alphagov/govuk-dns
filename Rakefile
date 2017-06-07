require 'rspec/core/rake_task'
require_relative './lib/tasks/utilities/common'

# Normal tests are anything not tagged 'validate_dns'
RSpec::Core::RakeTask.new(:rspec) do |t|
  t.rspec_opts = ['--tag', '~validate_dns', '-w']
end

RSpec::Core::RakeTask.new(:validate_dns) do |t|
  _check_for_missing_var('ZONEFILE')
  zonefile = ENV['ZONEFILE']
  if !File.exist?(zonefile)
    warn "Zonefile, #{zonefile}, not found."
    exit 1
  end
  t.rspec_opts = ['--tag', 'validate_dns']
end

FileList['lib/tasks/*.rake'].each do |rake_file|
  import rake_file
end

desc 'Generate and validate Terraform DNS configuration'
task generate: [:validate_generate_environment, :clean, :generate_terraform, :validate]
