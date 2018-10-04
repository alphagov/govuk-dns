module ZoneFileFieldValidator
  MIN_TTL = 300
  MAX_TTL = 86400 # 1 day

  def self.fqdn?(domainname)
    regex = %r{
      \A               # Match the start of the string
      [-a-z0-9_]+      # Match the first label made of numbers, letters and hyphens
      \.               # Make sure we have at least a TLD
      [-.a-z0-9_]*     # Other characters should alphanumeric, periods or hyphens
      \.               # Final character should be a period
      \z               # Match the end of the string
    }x

    # Use double bang to return a boolean
    !!(regex =~ domainname)
  end

  def self.ipv4?(address)
    regex = %r{
      \A                       # Start of string
      (?:                      # Non-capturing group to match digits plus a period
        (?:
          25[0-5]|             # Match digits 250-255
          2[0-4][0-9]|         # Match digits 200-249
          [01]?[0-9][0-9]?     # Match digits 0-199
        )\.                    # Match the period
      ){3}                     # Match three blocks of the blocks
      (?:
        25[0-5]|               # Match the final block
        2[0-4][0-9]|
        [01]?[0-9][0-9]?
      )
      \z                       # End of string
    }x

    !!(regex =~ address)
  end

  def self.ipv6?(address)
    regex = %r{
      \A
      (
        (
          (?=.*(::))
          (?!.*\3.+\3)
        )\3?|
        [\dA-F]{1,4}:
      )
      ([\dA-F]{1,4}(\3|:\b)|\2){5}
      (
        ([\dA-F]{1,4}(\3|:\b|$)|\2){2}|
        (((2[0-4]|1\d|[1-9])?\d|25[0-5])\.?\b){4}
      )
      \z
    }xi

    !!(regex =~ address)
  end

  def self.mx?(priority_and_domain)
    regex = %r{
      \A               # Start of string
      [0-9]*           # Match any number of digits which make up the priority
      \s               # Whitespace delineated fields
      (?<domain>.*)    # Capture the domain field for further testing
      \z               # End of string
    }x

    matches = regex.match(priority_and_domain)
    return false if matches.nil?

    fqdn?(matches['domain']) && matches[0] == priority_and_domain
  end

  def self.subdomain?(subdomain)
    return false if subdomain == '' # Should not be blank, should be '@'
    return true if subdomain == '@' # Reference to $ORIGIN
    # Allowed characters are numbers, lower-case letters, periods and hyphens per part
    # Wildcard character (*) is only allowed on its own in the least significant part
    regex = /\A(\*\.)?[-_.a-z0-9]*\z|\A\*\z/
    !!(regex =~ subdomain)
  end

  def self.txt_subdomain?(subdomain)
    return false if subdomain == '' # Should not be blank, should be '@'
    return true if subdomain == '@' # Reference to $ORIGIN
    # TXT subdomains may contain underscores and upper case letters in
    # addition to other subdomain characters
    regex = /\A[-_.a-zA-Z0-9]*\z/
    !!(regex =~ subdomain)
  end

  def self.txt_data_semicolons?(data)
    semicolons = data.scan(/;/).length
    esc_semicolons = data.scan(/(\\;)/).length

    if semicolons.positive?
      if esc_semicolons < semicolons
        return false
      end
    end
  end

  def self.ttl?(ttl)
    return false if /\A\d*\z/ !~ ttl # Not a valid integer string
    ttl = Integer(ttl)

    (MIN_TTL <= ttl) && (ttl <= MAX_TTL) # Check Bounds
  end

  def self.get_record_errors(record)
    errors = []

    ttl = record['ttl']
    data = record['data']
    type = record['record_type']
    subdomain = record['subdomain']

    # TTL tests
    if ttl.nil?
      errors << "Missing 'ttl' field in record #{record}."
    elsif ! ttl?(ttl)
      errors << "TTL must be an integer between #{MIN_TTL}s and #{MAX_TTL}s, got: '#{ttl}'."
    end

    # Basic data tests
    if data.nil?
      errors << "Missing 'data' field in record #{record}."
    end

    # Most of the validation for data relies on the record type
    case type
    when nil?
      errors << "Missing 'record_type' field in record #{record}."
    when 'A'
      errors << "A record data field must be an IPv4 address, got: '#{data}'." if ! ipv4?(data)
    when 'AAAA'
      errors << "AAAA record data field must be an IPv6 address, got: '#{data}'." if ! ipv6?(data)
    when 'NS'
      errors << "NS record data field must be a lower-case FQDN (with a trailing dot), got: '#{data}'." if ! fqdn?(data)
    when 'MX'
      errors << "MX record data field must be of the form '<priority> <lower-case FQDN>', got: '#{data}'." if ! mx?(data)
    when 'TXT'
      errors << "TXT record data field must not be empty." if data.empty?
      errors << "TXT record data semicolons should be escaped, got: '#{data}'." if ! txt_data_semicolons?(data).nil?
    when 'CNAME'
      errors << "CNAME record data field must be a lower-case FQDN (with a trailing dot), got: '#{data}'." if ! fqdn?(data)
    else
      errors << "Unknown record type: '#{type}'."
    end

    # Validation for subdomain only changes for TXT records
    if subdomain.nil?
      errors << "Missing 'subdomain' field in record #{record}."
    elsif type == 'TXT' && ! txt_subdomain?(subdomain)
      errors << "Invalid TXT subdomain field, must either be '@' or consist of numbers, letters, hyphens, periods and underscores; got: '#{subdomain}'."
    elsif type != 'TXT' && ! subdomain?(subdomain)
      errors << "Invalid #{type} subdomain field, must either be '@' or consist of numbers, letters, hyphens, periods, and wildcards; got: '#{subdomain}'."
    end

    errors
  end

  def self.get_zone_errors(zone_file)
    errors = []

    origin = zone_file['origin']
    records = zone_file['records']

    if origin.nil? || origin.empty?
      errors << "Origin field must be set"
    elsif ! fqdn?(origin)
      errors << "Origin must be a lower-case FQDN, got #{origin}"
    end

    if records.nil? || records.empty?
      errors << "No records found."
    else
      records.each { |rec|
        errors = errors + get_record_errors(rec)
      }
    end

    errors
  end
end
