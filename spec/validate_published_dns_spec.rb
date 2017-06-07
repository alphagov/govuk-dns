
#
# This spec compares the result of a DNS query with the contents of a YAML
# DNS zone file.
#
# The spec will split up a set of tests on a per subdomain basis. Then for each
# subdomain it will check that there are the expected number of records and
# that each record has the correct type, data and a valid TTL (one that is less
# than the maximum, set in the YAML).
#
# The YAML file is assumed to be one that passes the 'validate_yaml' task.
#

require "yaml"
require "fileutils"
require "dnsruby"

DOMAIN_IGNORE_LIST = %w{gke.integration}

# We set a tag on these tests as we do not want to run them as part of the main
# test suite.
RSpec.describe 'Validate the published DNS against the YAML.', validate_dns: true do
  zonefile = ENV['ZONEFILE']
  # Exit early if no zonefile given, or it doesn't exist.
  break if zonefile.nil? || !File.exist?(zonefile)
  yaml_dns = YAML.load_file(zonefile)

  origin = yaml_dns['origin']
  yaml_subdomains = yaml_dns['records'].group_by { |rec| rec['subdomain'] }

  custom_nameserver = ENV['CUSTOM_NS']
  if custom_nameserver
    puts "Querying #{custom_nameserver}"
    resolver = Dnsruby::Resolver.new({:nameserver => [custom_nameserver]})
  else
    resolver = Dnsruby::Resolver.new
  end

  yaml_subdomains.each { |subdomain, subdomain_records|
    describe "The '#{subdomain}' subdomain" do
      query = subdomain == '@' ? origin : "#{subdomain}.#{origin}"

      next if DOMAIN_IGNORE_LIST.include?(subdomain)

      # There are a couple of ways that the query can fail, this deals with the
      # two most likely: timeout and NXDomain.
      begin
        # Use 'ANY' to get all the records for the subdomain.
        records = resolver.query(query, 'ANY')
      rescue Dnsruby::NXDomain
        # NXDomain is a test failure let RSpec know.
        it 'should exist.' do
          expect(true).to be false, "NXDomain response, expected '#{subdomain}' to exist."
        end
        next
      rescue Dnsruby::ResolvTimeout
        # Timeout is not a test failure but we probably want to add a retry list
        # or similar for total validation.
        puts "Timeout getting response for '#{subdomain}'."
        next
      end

      # The YAML does not include SOA records so remove those.
      answers = records.answer.select { |ans| ans.type.to_s != 'SOA' }

      # We do not manage NS records for the root domain
      answers = answers.select { |ans| !(subdomain == '@' && ans.type.to_s == 'NS') }

      # If you query an authoritative nameserver then it may return a string of
      # related results until it provides the IP address. We're only interested
      # in the results for the specific record we are querying.
      answers = answers.select { |ans| ans.name.to_s == query.chomp(".") }

      it 'should have the expected number of results.' do
        expect(subdomain_records.length).to eq(answers.length), "expected #{subdomain_records.length} records, got: #{answers.length}."
      end

      answers.each { |ans|
        ans_type = ans.type.to_s
        ans_ttl = Integer(ans.ttl.to_s)

        it 'should be a known record type.' do
          expect(%w{A MX NS TXT CNAME}).to include(ans_type)
        end

        # DnsRuby doesn't provide a uniform way of getting the data field so
        # we have to parse it.
        ans_data = case ans_type
                   when 'TXT'
                     ans.rdata[0].to_s.gsub(';', '\;').gsub(' ', '\\ ')
                   when 'MX'
                     "#{ans.rdata[0]} #{ans.rdata[1]}."
                   when 'NS', 'CNAME'
                     # DnsRuby removes the trailing '.' from FQDNs but we need it.
                     "#{ans.rdata}."
                   when 'A'
                     ans.rdata.to_s
                   end

        it 'should have data' do
          expect(ans_data).to_not be_nil, "#{ans} should contain a data field."
        end

        # In theory we could roll all of our tests for the individual records
        # into some nested RSpec include/satisfy statements but by separately
        # finding the YAML record then testing against it we get better output.
        found = subdomain_records.select { |record|
          # TXT fields may be case sensitive but none of the other types we
          # currently check are (A, MX, NS, CNAME).
          if ans_type == 'TXT'
            record['record_type'] == ans_type &&
              record['data'] == ans_data
          elsif ! record['data'].nil? && ! ans_data.nil?
            record['record_type'] == ans_type &&
              record['data'].casecmp(ans_data) == 0
          end
        }

        # We assume that we will not get duplicate records back from DNS.
        it "'#{ans_type}' record should be in the YAML with data: '#{ans_data}'." do
          expect(found.length).to be(1), "Expected to find 1 copy of '#{ans}' in the YAML."
        end
        next if found.length != 1

        it "should have a TTL less than #{found[0]['ttl']}s." do
          expect(ans_ttl).to be <= found[0]['ttl'].to_i
        end
      }
    end
  }
end
