require_relative '../lib/tasks/zone_file_field_validator'

RSpec.describe 'Zone file field validators' do
  describe 'fqdn?', type: :class do
    it 'should be true for trivial examples' do
      expect(ZoneFileFieldValidator.fqdn?('example.com.')).to be true
    end

    it 'should be true for long examples' do
      expect(ZoneFileFieldValidator.fqdn?('this.is-a.surprisingly.long.example.1.com.')).to be true
    end

    it 'should be false for examples lacking a TLD' do
      expect(ZoneFileFieldValidator.fqdn?('example.')).to be false
    end

    it 'should be false for examples lacking a domain' do
      expect(ZoneFileFieldValidator.fqdn?('.com.')).to be false
    end

    it 'should be false for examples containing underscores' do
      expect(ZoneFileFieldValidator.fqdn?('bad_example.com.')).to be false
    end

    it 'should be false for examples lacking a trailing period' do
      expect(ZoneFileFieldValidator.fqdn?('bad_example.com')).to be false
    end

    it 'should be false for examples containing unicode' do
      expect(ZoneFileFieldValidator.fqdn?('båd_éxämple.com.')).to be false
    end

    it 'should be false for examples containing uppercase' do
      expect(ZoneFileFieldValidator.fqdn?('BAD_EXAMPLE.COM.')).to be false
    end
  end

  describe 'ipv4?' do
    it 'should be true for trivial examples' do
      expect(ZoneFileFieldValidator.ipv4?('127.0.0.1')).to be true
    end

    it 'should be true for the "minimum" value' do
      expect(ZoneFileFieldValidator.ipv4?('0.0.0.0')).to be true
    end

    it 'should be true for the "maximum" value' do
      expect(ZoneFileFieldValidator.ipv4?('255.255.255.255')).to be true
    end

    it 'should be false for values outside the maximum' do
      expect(ZoneFileFieldValidator.ipv4?('256.256.256.256')).to be false
    end

    it 'should be false for values with fewer than 4 blocks' do
      expect(ZoneFileFieldValidator.ipv4?('1.1.1')).to be false
    end

    it 'should be false for values with more than 4 blocks' do
      expect(ZoneFileFieldValidator.ipv4?('1.1.1.1.1')).to be false
    end

    it 'should be false for values that contain letters' do
      expect(ZoneFileFieldValidator.ipv4?('d.e.a.d')).to be false
    end
  end

  describe 'mx?' do
    it 'should be true for trivial examples' do
      expect(ZoneFileFieldValidator.mx?('10 example.com.')).to be true
    end

    it 'should be true for larger examples' do
      expect(ZoneFileFieldValidator.mx?('10412 longer.test-example.com.')).to be true
    end

    it 'should be false for strings not of the format "<priority> <fqdn>"' do
      expect(ZoneFileFieldValidator.mx?('10')).to be false
      expect(ZoneFileFieldValidator.mx?('example.com.')).to be false
      expect(ZoneFileFieldValidator.mx?('example.com. 10')).to be false
    end

    it 'should be false for strings with an invalid fqdn' do
      expect(ZoneFileFieldValidator.mx?('10 .com.')).to be false
      expect(ZoneFileFieldValidator.mx?('10 0.0.0.0')).to be false
      expect(ZoneFileFieldValidator.mx?('10 foo_bar.com')).to be false
      expect(ZoneFileFieldValidator.mx?('10 foo_bar.com.')).to be false
    end
  end

  describe 'subdomain?' do
    it 'should be true for "@" (reference to $ORIGIN' do
      expect(ZoneFileFieldValidator.subdomain?('@')).to be true
    end

    it 'should be true for any string of letters, numbers, periods and hyphens' do
      expect(ZoneFileFieldValidator.subdomain?('example')).to be true
      expect(ZoneFileFieldValidator.subdomain?('long-example66')).to be true
      expect(ZoneFileFieldValidator.subdomain?('dotted.example')).to be true
    end

    it 'should be false for strings that contain underscores' do
      expect(ZoneFileFieldValidator.subdomain?('bad_example')).to be false
    end

    it 'should be false for strings that contain @ in addition to other things' do
      expect(ZoneFileFieldValidator.subdomain?('b@d_example')).to be false
    end

    it 'should be false for strings that contain uppercase' do
      expect(ZoneFileFieldValidator.subdomain?('BAD_EXAMPLE')).to be false
    end
  end

  describe 'txt_subdomain?' do
    it 'should be true for "@" (reference to $ORIGIN' do
      expect(ZoneFileFieldValidator.txt_subdomain?('@')).to be true
    end

    it 'should be true for any string of letters, numbers, periods, hyphens and underscores' do
      expect(ZoneFileFieldValidator.txt_subdomain?('example')).to be true
      expect(ZoneFileFieldValidator.txt_subdomain?('long-example66')).to be true
      expect(ZoneFileFieldValidator.txt_subdomain?('dotted.example')).to be true
    end

    it 'should be true for strings that contain underscores' do
      expect(ZoneFileFieldValidator.txt_subdomain?('good_example')).to be true
    end

    it 'should be false for strings that contain @ in addition to other things' do
      expect(ZoneFileFieldValidator.txt_subdomain?('b@d_example')).to be false
    end
  end

  describe 'txt_data_whitespace?' do
    it 'should be nil when there is no whitespace' do
      expect(ZoneFileFieldValidator.txt_data_whitespace?('foobar')).to be_nil
    end

    it 'should be nil when there is escaped whitespace' do
      expect(ZoneFileFieldValidator.txt_data_whitespace?('foo\ bar')).to be_nil
    end

    it 'should be false when there is non-escaped whitespace' do
      expect(ZoneFileFieldValidator.txt_data_whitespace?('foo bar')).to be false
    end

    it 'should be false when there is both non-escaped whitespace and escaped whitespace' do
      expect(ZoneFileFieldValidator.txt_data_whitespace?('foo\ bar bar')).to be false
    end
  end

  describe 'txt_data_semicolons?' do
    it 'should be nil when there are no semicolons' do
      expect(ZoneFileFieldValidator.txt_data_semicolons?('foobar')).to be_nil
    end

    it 'should be nil when there is an escaped semicolon' do
      expect(ZoneFileFieldValidator.txt_data_semicolons?('foo\;bar')).to be_nil
    end

    it 'should be false when there is a non-escaped semicolon' do
      expect(ZoneFileFieldValidator.txt_data_semicolons?('foo;bar')).to be false
    end

    it 'should be false when there is both an escaped and non-escaped semicolon' do
      expect(ZoneFileFieldValidator.txt_data_semicolons?('foo\;bar;bar')).to be false
    end
  end

  describe 'ttl?' do
    min = ZoneFileFieldValidator::MIN_TTL
    max = ZoneFileFieldValidator::MAX_TTL

    it 'should return true for integers between MIN_TTL and MAX_TTL' do
      average_ttl = (min + max) / 2

      expect(ZoneFileFieldValidator.ttl?('3600')).to be true
      expect(ZoneFileFieldValidator.ttl?(average_ttl.to_s)).to be true
      expect(ZoneFileFieldValidator.ttl?(min.to_s)).to be true
      expect(ZoneFileFieldValidator.ttl?(max.to_s)).to be true
    end

    it 'should be false for TTLs out of range or that aren\'t number strings' do
      expect(ZoneFileFieldValidator.ttl?((min - 1).to_s)).to be false
      expect(ZoneFileFieldValidator.ttl?((max + 1).to_s)).to be false
      expect(ZoneFileFieldValidator.ttl?('abcd')).to be false
    end
  end

  describe 'get_record_errors' do
    it 'should return an empty array for valid records' do
      records = [{
          'ttl' => '3600',
          'record_type' => 'A',
          'subdomain' => 'subdomain',
          'data' => '127.0.0.1',
        }, {
          'ttl' => '3600',
          'record_type' => 'NS',
          'subdomain' => '@',
          'data' => 'ns.example.com.',
        }, {
          'ttl' => '3600',
          'record_type' => 'MX',
          'subdomain' => 'mail',
          'data' => '10 mail.example.com.',
        }, {
          'ttl' => '3600',
          'record_type' => 'TXT',
          'subdomain' => '@',
          'data' => '"arbitrary\ data\;\ and\ such"',
        }, {
          'ttl' => '3600',
          'record_type' => 'CNAME',
          'subdomain' => 'api',
          'data' => 'subdomain.com.',
        },
      ]

      records.each { |rec|
        expect(ZoneFileFieldValidator.get_record_errors(rec)).to be_empty
      }
    end

    it 'should raise errors for missing fields' do
      result = ZoneFileFieldValidator.get_record_errors({})

      expect(result.length).to be 4
    end

    it 'should allow TXT records to have underscores in their subdomain fields' do
      record = {
        'ttl' => '3600',
        'record_type' => 'TXT',
        'subdomain' => '_extra_test',
        'data' => '"arbitrary\ data\;\ and\ such"',
      }

      expect(ZoneFileFieldValidator.get_record_errors(record)).to be_empty
    end

    it 'should raise errors for non-escaped whitespace in a TXT data field' do
      record = {
        'ttl' => '3600',
        'record_type' => 'TXT',
        'subdomain' => '_extra_test',
        'data' => '"arbitrary\ data\; and such"',
      }

      result = ZoneFileFieldValidator.get_record_errors(record)
      expect(result.length).to be 1
    end

    it 'should raise errors for a non-escaped semicolon in a TXT data field' do
      record = {
        'ttl' => '3600',
        'record_type' => 'TXT',
        'subdomain' => '_extra_test',
        'data' => '"arbitrary\ data;\ and\ such"',
      }

      result = ZoneFileFieldValidator.get_record_errors(record)
      expect(result.length).to be 1
    end

    it 'should raise errors for simple errors' do
      record = {
        'ttl' => '0',
        'record_type' => 'NONEXISTANT RECORD TYPE',
        'subdomain' => 'b@d_domain.com'
      }
      result = ZoneFileFieldValidator.get_record_errors(record)
      expect(result.length).to be 4
    end
  end

  describe 'get_zone_errors' do
    it 'should raise an error for missing origin' do
      zone = {
        'origin' => 'example.com.',
        'records' => [{
            'ttl' => '3600',
            'record_type' => 'A',
            'subdomain' => 'subdomain',
            'data' => '127.0.0.1',
          },
        ],
      }
      result = ZoneFileFieldValidator.get_zone_errors(zone)

      expect(result).to be_empty
    end

    it 'should raise errors for missing or empty fields' do
      expect(ZoneFileFieldValidator.get_zone_errors({}).length).to be 2

      zone = {
        'origin' => '',
        'records' => [],
      }

      expect(ZoneFileFieldValidator.get_zone_errors(zone).length).to be 2
    end

    it 'should raise an error if the origin is not a FQDN' do
      zone = {
        'origin' => 'bad_domain.com',
        'records' => [{
            'ttl' => '3600',
            'record_type' => 'A',
            'subdomain' => 'subdomain',
            'data' => '127.0.0.1',
          },
        ],
      }

      expect(ZoneFileFieldValidator.get_zone_errors(zone).length).to be 1
    end
  end
end
