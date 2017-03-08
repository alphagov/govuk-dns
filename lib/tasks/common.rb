def _run_system_command(command)
  system(command)
  exit_code = $?.exitstatus

  if exit_code != 0
    raise "Running '#{command}' failed with code #{exit_code}"
  end
end

TMP_DIR = 'tf-tmp'.freeze

REQUIRED_ENV_VARS = {
  dyn: %w{DYN_ZONE_ID DYN_CUSTOMER_NAME DYN_PASSWORD DYN_USERNAME},
  gce: %w{GOOGLE_ZONE_NAME GOOGLE_DNS_NAME GOOGLE_CREDENTIALS GOOGLE_REGION},
  route53: %w{ROUTE53_ZONE_ID AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY},
}.freeze

ALLOWED_PROVIDERS = REQUIRED_ENV_VARS.keys.map(&:to_s)

def deploy_env
  ENV['DEPLOY_ENV']
end

def region
  ENV['REGION'] || 'eu-west-1'
end

def bucket_name
  ENV['BUCKET_NAME'] || 'dns-state-bucket-' + deploy_env
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
