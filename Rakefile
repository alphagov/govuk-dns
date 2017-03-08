require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:rspec)

FileList['lib/tasks/*.rake'].each do |rake_file|
  import rake_file
end

desc 'Generate and validate Terraform DNS configuration'
task generate: [:validate_generate_environment, :clean, :generate_terraform, :validate]
