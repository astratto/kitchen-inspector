require_relative 'support/spec_helper'

describe Inspector::DependencyInspector do
  let(:dependency_inspector) { generate_dependency_inspector }

  describe "#initialize" do
    describe "Repository Manager" do
      it "raises an error if an unsupported Repository Manager is specified" do
          config = StringIO.new
          config.puts "repository_manager :type => 'Unknown', :base_url => 'http://localhost:8080', :token =>'test_token'"
          config.puts "chef_server_url 'http://localhost:4000'"
          config.puts "chef_client_pem 'testclient.pem'"
          config.puts "chef_username 'test_user'"

          expect do
            Inspector::DependencyInspector.new config
          end.to raise_error(Inspector::RepositoryManagerError)
      end

      describe "Gitlab" do
        it "creates a valid Inspector with a full configuration" do
          config = StringIO.new
          config.puts "repository_manager :type => 'Gitlab', :base_url => 'http://localhost:8080', :token =>'test_token'"
          config.puts "chef_server_url 'http://localhost:4000'"
          config.puts "chef_client_pem 'testclient.pem'"
          config.puts "chef_username 'test_user'"

          inspector = Inspector::DependencyInspector.new config
          inspector
        end

        it "raises an error when Gitlab Token is not configured" do
          config = StringIO.new
          config.puts "repository_manager :type => 'Gitlab', :base_url => 'http://localhost:8080'"
          config.puts "chef_server_url 'http://localhost:4000'"
          config.puts "chef_client_pem 'testclient.pem'"
          config.puts "chef_username 'test_user'"

          expect do
            Inspector::DependencyInspector.new config
          end.to raise_error(Inspector::GitlabAccessNotConfiguredError)
        end

        it "raises an error when Gitlab Base Url is not configured" do
          config = StringIO.new
          config.puts "repository_manager :type => 'Gitlab', :token =>'test_token'"
          config.puts "chef_server_url 'http://localhost:4000'"
          config.puts "chef_client_pem 'testclient.pem'"
          config.puts "chef_username 'test_user'"

          expect do
            Inspector::DependencyInspector.new config
          end.to raise_error(Inspector::GitlabAccessNotConfiguredError)
        end
      end
    end

    it "raises an error when Chef Server Url is not configured" do
      config = StringIO.new
      config.puts "repository_manager :type => 'Gitlab', :base_url => 'http://localhost:8080', :token =>'test_token'"
      config.puts "chef_client_pem 'testclient.pem'"
      config.puts "chef_username 'test_user'"

      expect do
        Inspector::DependencyInspector.new config
      end.to raise_error(Inspector::ChefAccessNotConfiguredError)
    end

    it "raises an error when Chef Client PEM is not configured" do
      config = StringIO.new
      config.puts "repository_manager :type => 'Gitlab', :base_url => 'http://localhost:8080', :token =>'test_token'"
      config.puts "chef_server_url 'http://localhost:4000'"
      config.puts "chef_username 'test_user'"

      expect do
        Inspector::DependencyInspector.new config
      end.to raise_error(Inspector::ChefAccessNotConfiguredError)
    end

    it "raises an error when Chef Username is not configured" do
      config = StringIO.new
      config.puts "repository_manager :type => 'Gitlab', :base_url => 'http://localhost:8080', :token =>'test_token'"
      config.puts "chef_server_url 'http://localhost:4000'"
      config.puts "chef_client_pem 'testclient.pem'"

      expect do
        Inspector::DependencyInspector.new config
      end.to raise_error(Inspector::ChefAccessNotConfiguredError)
    end
  end

  describe "#update_status" do
    before(:each) do
      @dependency = Inspector::Dependency.new("test", ">= 0")
      @dependency.chef_versions = ["1.0.0", "1.0.1"]
      @dependency.repomanager_versions = ["1.0.0", "1.0.1"]
      @dependency.version_used = "1.0.1"
    end

    it "sets correct statuses for correct versions on both servers" do
      dependency_inspector.update_status(@dependency)
      @dependency.repomanager_status.should == "up-to-date"
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

    it "returns a warning when a newer version exists on the Repository Manager" do
      @dependency.chef_versions = ["1.0.0"]
      dependency_inspector.update_status(@dependency)
      @dependency.chef_status.should == "warning-chef"
    end

    it "returns an error for missing version on the Repository Manager" do
      @dependency.repomanager_versions = []
      dependency_inspector.update_status(@dependency)
      @dependency.repomanager_status.should == "error-repomanager"
    end

    it "returns a warning when a newer version exists on Chef Server" do
      @dependency.repomanager_versions = ["1.0.0"]
      dependency_inspector.update_status(@dependency)
      @dependency.repomanager_status.should == "warning-repomanager"
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
end