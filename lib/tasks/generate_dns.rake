require 'fileutils'
require 'digest'
require 'erb'
require 'yaml'

require_relative './common'

desc 'Validate the environment for generating resources'
task :validate_generate_environment do
  if providers.nil?
    warn "Please set the 'PROVIDERS' environment variable to any of #{ALLOWED_PROVIDERS.join(', ')} or all."
    exit 1
  end

  check_for_missing_var('ZONEFILE')
end

desc 'Validate the generated terraform'
task :validate do
  providers.each { |current_provider|
    puts "Validating #{current_provider} terraform"
    _run_system_command("terraform validate #{TMP_DIR}/#{current_provider}")
  }
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
task generate_terraform: [:validate_generate_environment, :clean] do
  Dir.mkdir(TMP_DIR) unless File.exist?(TMP_DIR)
  records = YAML.load(File.read(ENV['ZONEFILE']))

  # Apply the general transforms (clean the title & escape the data)
  records['records'].map! { |rec|
    # Terraform resource records cannot contain '.'s or '@'s
    rec['base_title'] = rec['subdomain'].tr('.', '_').tr('@', 'AT')
    # Terraform requires escaped slashes in its strings.
    # The 6 '\'s are required because of how gsub works (see https://www.ruby-forum.com/topic/143645)
    rec['data'].gsub!('\\', '\\\\\\')
    rec
  }

  # Route 53 and Dyn allow duplicate name/record type combinations
  if providers.include?('route53') || providers.include?('dyn')
    puts 'route53 or dyn magic'
    records['records'].map! { |rec|
      # Resources need to be unique (and records often aren't, e.g. we have many
      # '@' records) so use a hash of the title, data and type to lock uniqueness.
      record_md5 = _get_record_md5(rec['base_title'], rec['data'], rec['record_type'])
      rec['resource_title'] = "#{rec['base_title']}_#{record_md5}"
      rec
    }
  end

  # GCE expects data to be grouped by unique combinations of name & record type
  if providers.include? 'gce'
    puts 'GCE magic'
    records_grouped_by_name = records['records'].group_by {|rec| [rec['subdomain'], rec['record_type']]}

    grouped_records = records_grouped_by_name.map { |subdomain_and_type, record_set|
      subdomain, type = subdomain_and_type
      base_title = record_set[0]['base_title']

      all_data = record_set.collect{|r| r['data']}.sort
      record_md5 = _get_record_md5(base_title, all_data.join(' '), type)

      {
        'resource_title' => "#{base_title}_#{record_md5}",
        'subdomain' => subdomain,
        'record_type' => type,
        'ttl' => record_set.collect{|r| r['ttl'].to_i}.min.to_s,
        'data' => all_data
      }
    }
  end

  # Render all the expected files
  providers.each { |current_provider|
    renderer = ERB.new(File.read("templates/#{current_provider}.tf.erb"))
    provider_dir = "#{TMP_DIR}/#{current_provider}"
    Dir.mkdir(provider_dir) unless File.exist?(provider_dir)
    File.write("#{provider_dir}/zone.tf", renderer.result(binding))
  }
end

def _get_record_md5(title, data, type)
  md5 = Digest::MD5.new
  md5 << title
  md5 << data
  md5 << type
  md5.hexdigest
end
