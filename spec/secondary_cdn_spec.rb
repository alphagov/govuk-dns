require_relative "../lib/tasks/utilities/secondary_cdn"

RSpec.describe Executor do
    let(:executor) { described_class.new }
    let (:success_status) { double("success").tap {|status| allow(status).to receive(:success?).and_return(true) } }
    let (:failure_status) { double("failure").tap {|status| allow(status).to receive(:success?).and_return(false) } }

    describe "#run" do
        it "should print the command for successes" do
            allow(Open3).to receive(:capture2e).and_return ["", success_status]
            expect { executor.run("echo", "hello world") }.to output("$ echo hello\\ world\n").to_stdout
        end

        it "should print the output for failures" do
            allow(Open3).to receive(:capture2e).and_return ["some result", failure_status]
            expect { executor.run("echo", "hello world") }.to output("$ echo hello\\ world\nsome result\n").to_stdout
        end

        it "should return successes with output" do
            allow($stdout).to receive(:puts)
            allow(Open3).to receive(:capture2e).and_return ["some result", success_status]
            result = executor.run("echo", "hello world") 
            expect(result.success?).to be(true)
            expect(result.output).to eq("some result")
        end

        it "should return failures with output" do
            allow($stdout).to receive(:puts)
            allow(Open3).to receive(:capture2e).and_return ["some result", failure_status]
            result = executor.run("echo", "hello world") 
            expect(result.success?).to be(false)
            expect(result.output).to eq("some result")
        end

        it "should return SystemErrors with error messages" do
            allow($stdout).to receive(:puts)
            error = SystemCallError.new("Fake Errno::ENOENT:")
            allow(Open3).to receive(:capture2e).and_raise error
            result = executor.run("echo", "hello world") 
            expect(result.success?).to be(false)
            expect(result.output).to eq(error.message)
        end
    end
end

RSpec.describe AwsCli do
    let (:executor) { double("executor") }
    let (:cli) { described_class.new(executor) }
    let (:success_status) { Executor::Result.new("", true) }
    let (:failure_status) { Executor::Result.new("", false) }

    describe "#installed?" do
        it "should be installed if aws --version is successful" do
            expect(executor).to receive(:run).with("aws", "--version").and_return success_status
            expect(cli.installed?).to be(true)
        end

        it "should not be installed if aws --version is not successful" do
            expect(executor).to receive(:run).with("aws", "--version").and_return failure_status
            expect(cli.installed?).to be(false)
        end
    end

    describe "#signed_in?" do
        it "should be signed in if aws sts get-caller-identity is successful" do
            expect(executor).to receive(:run).with("aws", "sts", "get-caller-identity").and_return success_status
            expect(cli.signed_in?).to be(true)
        end

        it "should not be signed in if aws sts get-caller-identity is not successful" do
            expect(executor).to receive(:run).with("aws", "sts", "get-caller-identity").and_return failure_status
            expect(cli.signed_in?).to be(false)
        end
    end

    describe "#get_cnames" do
        it "should make two list-distributions calls and return the results as a hash" do
            expect(executor).to receive(:run)
                .with("aws", "cloudfront", "list-distributions", "--query", "DistributionList.Items[?Comment=='WWW'].DomainName | [0]", "--output", "text")
                .and_return Executor::Result.new("xxx.cloudfront.net", true)

            expect(executor).to receive(:run)
                .with("aws", "cloudfront", "list-distributions", "--query", "DistributionList.Items[?Comment=='Assets'].DomainName | [0]", "--output", "text")
                .and_return Executor::Result.new("yyy.cloudfront.net", true)

            expect(cli.get_cnames).to match({
                "www-cdn.production.govuk.service.gov.uk" => "xxx.cloudfront.net",
                "assets.publishing.service.gov.uk" => "yyy.cloudfront.net",
            })
        end
    end
end

RSpec.describe GcloudCli do
    let (:executor) { double("executor") }
    let (:cli) { described_class.new(executor) }
    let (:success_status) { Executor::Result.new("", true) }
    let (:failure_status) { Executor::Result.new("", false) }

    describe "#installed?" do
        it "should be installed if gcloud --version is successful" do
            expect(executor).to receive(:run).with("gcloud", "--version").and_return success_status
            expect(cli.installed?).to be(true)
        end

        it "should not be installed if gcloud --version is not successful" do
            expect(executor).to receive(:run).with("gcloud", "--version").and_return failure_status
            expect(cli.installed?).to be(false)
        end
    end

    describe "#signed_in?" do
        it "should be signed in if gcloud auth print-access-token is successful" do
            expect(executor).to receive(:run).with("gcloud", "auth", "print-access-token").and_return success_status
            expect(cli.signed_in?).to be(true)
        end

        it "should not be signed in if aws sts get-caller-identity is not successful" do
            expect(executor).to receive(:run).with("gcloud", "auth", "print-access-token").and_return failure_status
            expect(cli.signed_in?).to be(false)
        end
    end

    describe "#target_is_production?" do
        it "should error if it can't get the project" do
            expect(executor).to receive(:run).with("gcloud", "config", "get-value", "project").and_return failure_status
            expect {cli.target_is_production?}.to raise_error(matching("Failed to get current gcloud project"))
        end

        it "should return true if the project is govuk-production" do
            expect(executor).to receive(:run).with("gcloud", "config", "get-value", "project").and_return Executor::Result.new("govuk-production", true)
            expect(cli.target_is_production?).to be(true)
        end

        it "should return false if the project is not govuk-production" do
            allow($stdout).to receive(:puts)
            expect(executor).to receive(:run).with("gcloud", "config", "get-value", "project").and_return Executor::Result.new("govuk-integration", true)
            expect(cli.target_is_production?).to be(false)
        end

        it "should print the name of the project if it is not govuk-production" do
            expect(executor).to receive(:run).with("gcloud", "config", "get-value", "project").and_return Executor::Result.new("govuk-integration", true)
            expect{cli.target_is_production?}.to output("govuk-integration\n").to_stdout
        end
    end
end

RSpec.describe SecondaryCDN do
    let (:secondary_cdn) { described_class.new }

    describe "#confirm_changes" do
        it "should print a message telling the user what changes need to be made to DNS" do
            expect(STDIN).to receive(:gets).and_return "Yes"
            expect { secondary_cdn.confirm_changes({ "www.example.com" => "aaa.cloudfront.net", "www.google.com" => "bbb.cloudfront.net" }) }.to output(
                a_string_matching("The following 4 DNS changes need to be made:")
                .and(a_string_matching('\* \[ \] Change the CNAME on www.example.com to aaa.cloudfront.net in AWS'))
                .and(a_string_matching('\* \[ \] Change the CNAME on www.example.com to aaa.cloudfront.net in GCP'))
                .and(a_string_matching('\* \[ \] Change the CNAME on www.google.com to bbb.cloudfront.net in AWS'))
                .and(a_string_matching('\* \[ \] Change the CNAME on www.google.com to bbb.cloudfront.net in GCP'))
            ).to_stdout
        end

        it "should exit if the user says No" do
            allow($stdout).to receive(:puts)
            allow($stdout).to receive(:printf)
            expect(STDIN).to receive(:gets).and_return "No"
            expect { secondary_cdn.confirm_changes({}) }.to raise_error SystemExit
        end

        it "should ask again if the user says anything else" do
            allow($stdout).to receive(:puts)
            allow($stdout).to receive(:printf)
            expect(STDIN).to receive(:gets).and_return "Banana"
            expect(STDIN).to receive(:gets).and_return "Peach"
            expect(STDIN).to receive(:gets).and_return "Apple"
            expect(STDIN).to receive(:gets).and_return "No"
            expect { secondary_cdn.confirm_changes({}) }.to raise_error SystemExit
        end


    end
end