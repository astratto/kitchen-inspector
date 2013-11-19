require_relative 'support/spec_helper'

describe Inspector::DependencyInspector do
  let(:dependency_inspector) { generate_dependency_inspector }

  describe "#initialize" do
    it "creates a valid Inspector with a full configuration" do
      config = StringIO.new
      config.puts "gitlab_base_url 'http://localhost:8080'"
      config.puts "gitlab_token 'test_token'"
      config.puts "chef_server_url 'http://localhost:4000'"
      config.puts "chef_client_pem 'testclient.pem'"
      config.puts "chef_username 'test_user'"

      inspector = Inspector::DependencyInspector.new config
      inspector
    end

    it "raises an error when Gitlab Token is not configured" do
      config = StringIO.new
      config.puts "gitlab_base_url 'http://localhost:8080'"
      config.puts "chef_server_url 'http://localhost:4000'"
      config.puts "chef_client_pem 'testclient.pem'"
      config.puts "chef_username 'test_user'"

      expect do
        inspector = Inspector::DependencyInspector.new config
      end.to raise_error(Inspector::GitlabAccessNotConfiguredError)
    end

    it "raises an error when Gitlab Base Url is not configured" do
      config = StringIO.new
      config.puts "gitlab_token 'test_token'"
      config.puts "chef_server_url 'http://localhost:4000'"
      config.puts "chef_client_pem 'testclient.pem'"
      config.puts "chef_username 'test_user'"

      expect do
        inspector = Inspector::DependencyInspector.new config
      end.to raise_error(Inspector::GitlabAccessNotConfiguredError)
    end

    it "raises an error when Chef Server Url is not configured" do
      config = StringIO.new
      config.puts "gitlab_token 'test_token'"
      config.puts "gitlab_base_url 'http://localhost:8080'"
      config.puts "chef_client_pem 'testclient.pem'"
      config.puts "chef_username 'test_user'"

      expect do
        inspector = Inspector::DependencyInspector.new config
      end.to raise_error(Inspector::ChefAccessNotConfiguredError)
    end

    it "raises an error when Chef Client PEM is not configured" do
      config = StringIO.new
      config.puts "gitlab_token 'test_token'"
      config.puts "gitlab_base_url 'http://localhost:8080'"
      config.puts "chef_server_url 'http://localhost:4000'"
      config.puts "chef_username 'test_user'"

      expect do
        inspector = Inspector::DependencyInspector.new config
      end.to raise_error(Inspector::ChefAccessNotConfiguredError)
    end

    it "raises an error when Chef Username is not configured" do
      config = StringIO.new
      config.puts "gitlab_token 'test_token'"
      config.puts "gitlab_base_url 'http://localhost:8080'"
      config.puts "chef_server_url 'http://localhost:4000'"
      config.puts "chef_client_pem 'testclient.pem'"

      expect do
        inspector = Inspector::DependencyInspector.new config
      end.to raise_error(Inspector::ChefAccessNotConfiguredError)
    end
  end

  describe "#update_status" do
    before(:each) do
      @dependency = Inspector::Dependency.new("test", ">= 0")
      @dependency.chef_versions = ["1.0.0", "1.0.1"]
      @dependency.gitlab_versions = ["1.0.0", "1.0.1"]
      @dependency.version_used = "1.0.1"
    end

    it "sets correct statuses for correct versions on both servers" do
      dependency_inspector.update_status(@dependency)
      @dependency.gitlab_status.should == "up-to-date"
      @dependency.chef_status.should == "up-to-date"
      @dependency.status.should == "up-to-date"
    end

    it "returns an error when a valid version cannot be found" do
      @dependency.version_used = nil
      dependency_inspector.update_status(@dependency)
      @dependency.status.should == "error"
    end

    it "returns a warning when a newer version could be used" do
      @dependency.version_used = "1.0.0"
      dependency_inspector.update_status(@dependency)
      @dependency.status.should == "warning-req"
    end

    it "returns an error for missing version on Chef Server" do
      @dependency.chef_versions = []
      dependency_inspector.update_status(@dependency)
      @dependency.chef_status.should == "error-chef"
    end

    it "returns a warning when a newer version exists on Gitlab" do
      @dependency.chef_versions = ["1.0.0"]
      dependency_inspector.update_status(@dependency)
      @dependency.chef_status.should == "warning-chef"
    end

    it "returns an error for missing version on Gitlab" do
      @dependency.gitlab_versions = []
      dependency_inspector.update_status(@dependency)
      @dependency.gitlab_status.should == "error-gitlab"
    end

    it "returns a warning when a newer version exists on Chef Server" do
      @dependency.gitlab_versions = ["1.0.0"]
      dependency_inspector.update_status(@dependency)
      @dependency.gitlab_status.should == "warning-gitlab"
    end
  end

  describe "#satisfy" do
    it "returns the correct version when existing" do
      version = dependency_inspector.satisfy("~> 1.0.1", ["1.0.0", "1.0.1"])
      version.should == "1.0.1"
    end

    it "returns nil when a satisfying version doesn't exist" do
      version = dependency_inspector.satisfy("~> 1.0.1", ["1.0.0"])
      version.should == nil
    end
  end

  describe "#find_chef_server_versions" do
    it "retrieves versions using a valid project"
  end

  describe "#find_gitlab_versions" do
    it "retrieves versions using a valid project"
  end

  describe "#retrieve_dependencies" do
    it "retrieves the nested dependencies"
  end
end