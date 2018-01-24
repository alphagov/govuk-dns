require 'yaml'

TMP_DIR = 'tf-tmp'.freeze

REQUIRED_ENV_VARS = {
  gcp: {
    env: %w{GOOGLE_CREDENTIALS GOOGLE_REGION GOOGLE_PROJECT}.freeze,
  }.freeze,
  aws: {
    env: %w{AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION}.freeze,
  }.freeze,
}.freeze

ALLOWED_PROVIDERS = REQUIRED_ENV_VARS.keys.map(&:to_s).freeze

def required_from_env(var, msg = "Please set the '#{var}' environment variable.")
  unless ENV.include?(var)
    abort(msg)
  end
  ENV[var]
end

def statefile_name
  if ENV['ZONEFILE'].nil?
    return "terraform.tfstate"
  else
    # Statefile called publishing-service-gov-uk.tfstate
    filename = ENV['ZONEFILE'].split('/')[-1]
    return filename.gsub('.yaml', '').tr('.', '-') + ".tfstate"
  end
end

def deploy_env
  required_from_env('DEPLOY_ENV')
end

def zonefile
  required_from_env('ZONEFILE')
end

def region
  ENV['REGION'] || 'eu-west-1'
end

def bucket_name
  ENV['BUCKET_NAME'] || 'dns-state-bucket-' + deploy_env
end

def providers
  if not ENV['PROVIDERS'].nil?
    return [ENV['PROVIDERS']]
  end

  abort("Please set the 'PROVIDERS' environment variable to one of: #{ALLOWED_PROVIDERS.join(', ')}")
end
