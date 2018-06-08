require 'rspec/core/rake_task'
require_relative './lib/tasks/utilities/common'

# Normal tests are anything not tagged 'validate_dns'
RSpec::Core::RakeTask.new(:rspec) do |t|
  t.rspec_opts = ['--tag', '~validate_dns']
end

task default: [:rspec]

RSpec::Core::RakeTask.new(:validate_dns) do |t|
  if !File.exist?(zonefile)
    abort("Zonefile, #{zonefile}, not found.")
  end
  t.rspec_opts = ['--tag', 'validate_dns']
end

FileList['lib/tasks/*.rake'].each do |rake_file|
  import rake_file
end
