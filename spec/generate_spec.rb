require_relative '../lib/tasks/generate'
require_relative '../lib/tasks/common'

RSpec.describe 'generate' do
  describe '_get_tf_safe_title' do
    it 'should replace "@" with "AT"' do
      expect(_get_tf_safe_title('@')).to eq('AT')
    end

    it 'should replace "."s with "_"s' do
      expect(_get_tf_safe_title('foo.bar')).to eq('foo_bar')
    end

    it 'should not change other titles' do
      expect(_get_tf_safe_title('unchanged')).to eq('unchanged')
    end
  end

  describe '_get_tf_safe_data' do
    it 'should replace "\\" with "\\\\"' do
      expect(_get_tf_safe_data('\\')).to eq('\\\\')
    end

    it 'should not affect other data' do
      expect(_get_tf_safe_data('unchanged')).to eq('unchanged')
    end
  end

  describe '_get_record_md5' do
    it 'should return a hash' do
      expect(_get_record_md5('example', ['example'], 'NS')).to eq("55cd7429f772c0fe946b45e0f3d5a212")
    end

    it 'should be change based on title' do
      expect(_get_record_md5('CHANGED', ['example'], 'NS')).to_not eq(_get_record_md5('example', ['example'], 'NS'))
    end

    it 'should be change based on data' do
      expect(_get_record_md5('example', ['CHANGED'], 'NS')).to_not eq(_get_record_md5('example', ['example'], 'NS'))
    end

    it 'should be change based on TYPE' do
      expect(_get_record_md5('example', ['example'], 'TXT')).to_not eq(_get_record_md5('example', ['example'], 'NS'))
    end

    it 'should be the same regardless of data order' do
      data = %w{example1 anotherexample}
      expect(_get_record_md5('example', data, 'NS')).to eq(_get_record_md5('example', data.reverse, 'NS'))
    end
  end

  describe '_get_resource_title' do
    it 'should produce a unique safe tf title' do
      expect(_get_resource_title('example', ['example'], 'NS')).to eq('example_55cd7429f772c0fe946b45e0f3d5a212')
    end

    it 'should produce a unique safe tf title' do
      expect(_get_resource_title('@', ['example'], 'NS')).to eq('AT_1ffd35c18f40ad72f2dd9ecb22d2e863')
    end
  end

  describe '_get_tf_variables' do
    it 'should produce a hash with keys set to the values passed in' do
      expect(_get_tf_variables(%w{a b c})).to eq(
        'a' => {},
        'b' => {},
        'c' => {},
      )
    end
  end

  describe '_get_gce_resource' do
    it 'should produce an object which matches the gce cloudDNS terraform resource' do
      records = [
        {
          'record_type' => 'NS',
          'subdomain' => '@',
          'ttl' => '86400',
          'data' => 'example.com.',
        }
      ]
      expect = {
        google_dns_record_set: {
          'AT_4be974591aeffe148587193aac4d4b63' => {
            managed_zone: '${var.GOOGLE_ZONE_NAME}',
            name: '@.${var.GOOGLE_DNS_NAME}',
            type: 'NS',
            ttl: '86400',
            rrdatas: ['example.com.'],
          }
        }
      }

      expect(_get_gce_resource(records)).to eq(expect)
    end

    it 'should group records by subdomain and type' do
      records = [
        {
          'record_type' => 'NS',
          'subdomain' => '@',
          'ttl' => '86400',
          'data' => 'example.com.',
        },
        {
          'record_type' => 'NS',
          'subdomain' => '@',
          'ttl' => '86400',
          'data' => 'example2.com.',
        }
      ]
      expect = {
        google_dns_record_set: {
          'AT_5e340d3857c592022bb02576e7b16a3b' => {
            managed_zone: '${var.GOOGLE_ZONE_NAME}',
            name: '@.${var.GOOGLE_DNS_NAME}',
            type: 'NS',
            ttl: '86400',
            rrdatas: ['example.com.', 'example2.com.'],
          }
        }
      }

      expect(_get_gce_resource(records)).to eq(expect)
    end
  end

  describe '_get_route53_resource' do
    it 'should produce an object which matches the route53 terraform resource' do
      records = [
        {
          'record_type' => 'NS',
          'subdomain' => '@',
          'ttl' => '86400',
          'data' => 'example.com.',
        }
      ]
      expect = {
        aws_route53_record: {
          'AT_4be974591aeffe148587193aac4d4b63' => {
            zone_id: '${var.ROUTE53_ZONE_ID}',
            name: '@',
            type: 'NS',
            ttl: '86400',
            records: ['example.com.'],
          }
        }
      }

      expect(_get_route53_resource(records)).to eq(expect)
    end

    it 'should not group records' do
      records = [
        {
          'record_type' => 'NS',
          'subdomain' => '@',
          'ttl' => '86400',
          'data' => 'example.com.',
        },
        {
          'record_type' => 'NS',
          'subdomain' => '@',
          'ttl' => '86400',
          'data' => 'example2.com.',
        }
      ]
      expect = {
        aws_route53_record: {
          'AT_4be974591aeffe148587193aac4d4b63' => {
            zone_id: '${var.ROUTE53_ZONE_ID}',
            name: '@',
            type: 'NS',
            ttl: '86400',
            records: ['example.com.'],
          },
          'AT_1d8dc76cba0c12fb7e82e3141e3d45f7' => {
            zone_id: '${var.ROUTE53_ZONE_ID}',
            name: '@',
            type: 'NS',
            ttl: '86400',
            records: ['example2.com.'],
          }
        }
      }

      expect(_get_route53_resource(records)).to eq(expect)
    end
  end

  describe '_get_dyn_resource' do
    it 'should produce an object which matches the dyn terraform resource' do
      records = [
        {
          'record_type' => 'NS',
          'subdomain' => '@',
          'ttl' => '86400',
          'data' => 'example.com.',
        }
      ]
      expect = {
        dyn_record: {
          'AT_4be974591aeffe148587193aac4d4b63' => {
            zone: '${var.DYN_ZONE_ID}',
            name: '@',
            type: 'NS',
            ttl: '86400',
            value: 'example.com.',
          }
        }
      }

      expect(_get_dyn_resource(records)).to eq(expect)
    end

    it 'should not group records' do
      records = [
        {
          'record_type' => 'NS',
          'subdomain' => '@',
          'ttl' => '86400',
          'data' => 'example.com.',
        },
        {
          'record_type' => 'NS',
          'subdomain' => '@',
          'ttl' => '86400',
          'data' => 'example2.com.',
        }
      ]
      expect = {
        dyn_record: {
          'AT_4be974591aeffe148587193aac4d4b63' => {
            zone: '${var.DYN_ZONE_ID}',
            name: '@',
            type: 'NS',
            ttl: '86400',
            value: 'example.com.',
          },
          'AT_1d8dc76cba0c12fb7e82e3141e3d45f7' => {
            zone: '${var.DYN_ZONE_ID}',
            name: '@',
            type: 'NS',
            ttl: '86400',
            value: 'example2.com.',
          }
        }
      }

      expect(_get_dyn_resource(records)).to eq(expect)
    end
  end

  describe '_generate_terraform_object' do
    it 'should be side-effect free for all providers' do
      records = [
        {
          'record_type' => 'NS',
          'subdomain' => '@',
          'ttl' => '86400',
          'data' => 'ns1.example.com.',
        }.freeze,
        {
          'record_type' => 'NS',
          'subdomain' => '@',
          'ttl' => '86400',
          'data' => 'ns2.example.com.',
        }.freeze,
        {
          'record_type' => 'TXT',
          'subdomain' => 'sub.',
          'ttl' => '3600',
          'data' => 'Some test',
        }.freeze,
        {
          'record_type' => 'A',
          'subdomain' => 'sub.',
          'ttl' => '3600',
          'data' => '123.233.10.1',
        }.freeze,
      ].freeze

      ALLOWED_PROVIDERS.each {|current_provider|
        vars = REQUIRED_ENV_VARS[current_provider.to_sym][:tf]
        result = nil
        # Because the records are frozen this (should) error if they're modified
        expect {
          result = _generate_terraform_object(current_provider, records, vars)
        }.to_not raise_error

        expect(result).to include(:resource, :variable)
      }
    end
  end
end
