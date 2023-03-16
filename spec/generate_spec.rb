require_relative "../lib/tasks/utilities/generate"
require_relative "../lib/tasks/utilities/common"

RSpec.describe "generate" do
  describe "_get_tf_safe_title" do
    it 'should replace "@" with "AT"' do
      expect(_get_tf_safe_title("@")).to eq("AT")
    end

    it 'should replace "."s with "_"s' do
      expect(_get_tf_safe_title("foo.bar")).to eq("foo_bar")
    end

    it 'should replace "*"s with "WILDCARD"s' do
      expect(_get_tf_safe_title("*.bar")).to eq("WILDCARD_bar")
    end

    it "should not change other titles" do
      expect(_get_tf_safe_title("unchanged")).to eq("unchanged")
    end
  end

  describe "_get_tf_safe_data" do
    it 'should replace "\\" with "\\\\"' do
      expect(_get_tf_safe_data("\\")).to eq("\\\\")
    end

    it "should not affect other data" do
      expect(_get_tf_safe_data("unchanged")).to eq("unchanged")
    end
  end

  describe "_get_resource_title" do
    it "should produce a unique safe tf title" do
      expect(_get_resource_title("example", "NS")).to eq("NS_example")
    end

    it "should produce a unique safe tf title" do
      expect(_get_resource_title("@", "NS")).to eq("NS_AT")
    end
  end

  describe "_get_gcp_resource" do
    it "should produce an object which matches the gcp cloudDNS terraform resource" do
      origin = "my.dnsname.com."
      deployment = {
        "zone_name" => "my-google-zone",
      }
      records = [
        {
          "record_type" => "NS",
          "subdomain" => "test",
          "ttl" => "86400",
          "data" => "example.com.",
        },
      ]
      expect = {
        "NS_test" => {
          managed_zone: "my-google-zone",
          name: "test.my.dnsname.com.",
          type: "NS",
          ttl: "86400",
          rrdatas: ["example.com."],
        },
      }

      expect(_get_gcp_resource(records, origin, deployment)).to eq(expect)
    end

    it "should split long data lines to a maximum of 255 characters with spaces" do
      origin = "my.dnsname.com."
      deployment = {
        "zone_name" => "my-google-zone",
      }
      data = "123456790" * 30
      records = [
        {
          "record_type" => "TXT",
          "subdomain" => "test",
          "ttl" => "86400",
          "data" => data,
        },
      ]
      rrdatas = ["123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123 456790123456790"]
      result = _get_gcp_resource(records, origin, deployment)
      test_id = result.keys.first
      expect(result[test_id][:rrdatas]).to eq(rrdatas)
    end

    it 'should not include the "@" in the name field' do
      origin = "my.dnsname.com."
      deployment = {
        "zone_name" => "my-google-zone",
      }
      records = [
        {
          "record_type" => "NS",
          "subdomain" => "@",
          "ttl" => "86400",
          "data" => "example.com.",
        },
      ]

      result = _get_gcp_resource(records, origin, deployment)
      expect(result["NS_AT"][:name]).to eq("my.dnsname.com.")
    end

    it "should group records by subdomain and type" do
      origin = "my.dnsname.com."
      deployment = {
        "zone_name" => "my-google-zone",
      }
      records = [
        {
          "record_type" => "NS",
          "subdomain" => "test",
          "ttl" => "86400",
          "data" => "example.com.",
        },
        {
          "record_type" => "NS",
          "subdomain" => "test",
          "ttl" => "86400",
          "data" => "example2.com.",
        },
      ]
      expect = {
        "NS_test" => {
          managed_zone: "my-google-zone",
          name: "test.my.dnsname.com.",
          type: "NS",
          ttl: "86400",
          rrdatas: ["example.com.", "example2.com."],
        },
      }

      expect(_get_gcp_resource(records, origin, deployment)).to eq(expect)
    end
  end

  describe "_get_aws_resource" do
    it "should produce an object which matches the route53 terraform resource" do
      deployment = { "zone_id" => "route53zoneid" }
      records = [
        {
          "record_type" => "NS",
          "subdomain" => "@",
          "ttl" => "86400",
          "data" => "example.com.",
        },
      ]
      expect = {
        "NS_AT" => {
          zone_id: "route53zoneid",
          name: "",
          type: "NS",
          ttl: "86400",
          records: ["example.com."],
        },
      }

      expect(_get_aws_resource(records, deployment)).to eq(expect)
    end

    it "should split long data lines to a maximum of 255 characters with escaped quotes" do
      deployment = { "zone_id" => "route53zoneid" }
      data = "123456790" * 30
      records = [
        {
          "record_type" => "TXT",
          "subdomain" => "test",
          "ttl" => "86400",
          "data" => data,
        },
      ]
      expected = ["123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123456790123\"\"456790123456790"]
      result = _get_aws_resource(records, deployment)
      test_id = result.keys.first
      expect(result[test_id][:records]).to eq(expected)
    end

    it 'should not include the "@" in the name field' do
      deployment = { "zone_id" => "route53zoneid" }
      records = [
        {
          "record_type" => "NS",
          "subdomain" => "@",
          "ttl" => "86400",
          "data" => "example.com.",
        },
      ]

      result = _get_aws_resource(records, deployment)
      expect(result["NS_AT"][:name]).to eq("")
    end

    it "should group records by subdomain and type" do
      deployment = { "zone_id" => "route53zoneid" }
      records = [
        {
          "record_type" => "NS",
          "subdomain" => "@",
          "ttl" => "86400",
          "data" => "example.com.",
        },
        {
          "record_type" => "NS",
          "subdomain" => "@",
          "ttl" => "86400",
          "data" => "example2.com.",
        },
      ]
      expect = {
        "NS_AT" => {
          zone_id: "route53zoneid",
          name: "",
          type: "NS",
          ttl: "86400",
          records: ["example.com.", "example2.com."],
        },
      }

      expect(_get_aws_resource(records, deployment)).to eq(expect)
    end
  end

  describe "_generate_terraform_object" do
    it "should be side-effect free for all providers and contain the correct resource" do
      statefile_name = "test/example.tfvars"
      region = "eu-west-1"
      deploy_env = "test"

      records = [
        {
          "record_type" => "NS",
          "subdomain" => "@",
          "ttl" => "86400",
          "data" => "ns1.example.com.",
        }.freeze,
        {
          "record_type" => "NS",
          "subdomain" => "@",
          "ttl" => "86400",
          "data" => "ns2.example.com.",
        }.freeze,
        {
          "record_type" => "TXT",
          "subdomain" => "sub.",
          "ttl" => "3600",
          "data" => "Some test",
        }.freeze,
        {
          "record_type" => "A",
          "subdomain" => "sub.",
          "ttl" => "3600",
          "data" => "123.233.10.1",
        }.freeze,
      ].freeze

      origin = "my.dnsname.com."
      deployment = {
        "gcp" => {
          "dns_name" => "my.dnsname.com.",
        },
        "aws" => {
          "zone_id" => "route53zoneid",
        },
      }

      expected_resource_names = {
        "gcp" => :google_dns_record_set,
        "aws" => :aws_route53_record,
      }.freeze

      ALLOWED_PROVIDERS.each do |current_provider|
        result = nil
        # Because the records are frozen this (should) error if they're modified
        expect {
          result = generate_terraform_object(statefile_name, region, deploy_env, current_provider, origin, records, deployment)
        }.to_not raise_error

        expect(result).to include(:resource)
        expect(result[:resource]).to include(expected_resource_names[current_provider])
      end
    end
  end
end
