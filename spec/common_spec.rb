require_relative "../lib/tasks/utilities/common"

RSpec.describe "Common tasks" do
  describe "statefile_name" do
    it 'should return "terraform.tfstate" by default' do
      expect(statefile_name).to eq "terraform.tfstate"
    end

    it "should return munged ZONEFILE name if set" do
      ENV["ZONEFILE"] = "foo.bar.baz.yaml"
      expect(statefile_name).to eq "foo-bar-baz.tfstate"
    end

    it "should remove path fragments from the ZONEFILE name if set" do
      ENV["ZONEFILE"] = "some/path/foo.bar.baz.yaml"
      expect(statefile_name).to eq "foo-bar-baz.tfstate"
    end
  end
end
