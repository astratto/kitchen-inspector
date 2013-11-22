require_relative 'support/spec_helper'

describe DependencyInspector do
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
            DependencyInspector.new config
          end.to raise_error(RepositoryManagerError)
      end

      describe "Gitlab" do
        it "creates a valid Inspector with a full configuration" do
          config = StringIO.new
          config.puts "repository_manager :type => 'Gitlab', :base_url => 'http://localhost:8080', :token =>'test_token'"
          config.puts "chef_server_url 'http://localhost:4000'"
          config.puts "chef_client_pem 'testclient.pem'"
          config.puts "chef_username 'test_user'"

          inspector = DependencyInspector.new config
          inspector
        end

        it "raises an error when Gitlab Token is not configured" do
          config = StringIO.new
          config.puts "repository_manager :type => 'Gitlab', :base_url => 'http://localhost:8080'"
          config.puts "chef_server_url 'http://localhost:4000'"
          config.puts "chef_client_pem 'testclient.pem'"
          config.puts "chef_username 'test_user'"

          expect do
            DependencyInspector.new config
          end.to raise_error(GitlabAccessNotConfiguredError)
        end

        it "raises an error when Gitlab Base Url is not configured" do
          config = StringIO.new
          config.puts "repository_manager :type => 'Gitlab', :token =>'test_token'"
          config.puts "chef_server_url 'http://localhost:4000'"
          config.puts "chef_client_pem 'testclient.pem'"
          config.puts "chef_username 'test_user'"

          expect do
            DependencyInspector.new config
          end.to raise_error(GitlabAccessNotConfiguredError)
        end
      end
    end

    it "raises an error when Chef Server Url is not configured" do
      config = StringIO.new
      config.puts "repository_manager :type => 'Gitlab', :base_url => 'http://localhost:8080', :token =>'test_token'"
      config.puts "chef_client_pem 'testclient.pem'"
      config.puts "chef_username 'test_user'"

      expect do
        DependencyInspector.new config
      end.to raise_error(ChefAccessNotConfiguredError)
    end

    it "raises an error when Chef Client PEM is not configured" do
      config = StringIO.new
      config.puts "repository_manager :type => 'Gitlab', :base_url => 'http://localhost:8080', :token =>'test_token'"
      config.puts "chef_server_url 'http://localhost:4000'"
      config.puts "chef_username 'test_user'"

      expect do
        DependencyInspector.new config
      end.to raise_error(ChefAccessNotConfiguredError)
    end

    it "raises an error when Chef Username is not configured" do
      config = StringIO.new
      config.puts "repository_manager :type => 'Gitlab', :base_url => 'http://localhost:8080', :token =>'test_token'"
      config.puts "chef_server_url 'http://localhost:4000'"
      config.puts "chef_client_pem 'testclient.pem'"

      expect do
        DependencyInspector.new config
      end.to raise_error(ChefAccessNotConfiguredError)
    end
  end

  describe "#update_status" do
    before(:each) do
      @dependency = Dependency.new("test", ">= 0")
      @dependency.chef_versions = ["1.0.0", "1.0.1"]
      @dependency.repomanager_tags = ["1.0.0", "1.0.1"]
      @dependency.latest_metadata_repomanager = Solve::Version.new("1.0.1")
      @dependency.latest_tag_repomanager = Solve::Version.new("1.0.1")
      @dependency.latest_chef = Solve::Version.new("1.0.1")
      @dependency.version_used = "1.0.1"
    end

    it "sets correct statuses for correct versions on both servers" do
      dependency_inspector.update_status(@dependency)
      @dependency.repomanager_status.should == :'up-to-date'
      @dependency.chef_status.should == :'up-to-date'
      @dependency.status.should == :'up-to-date'
    end

    it "returns an error when a valid version cannot be found" do
      @dependency.version_used = nil

      dependency_inspector.update_status(@dependency)
      @dependency.status.should == :error
    end

    it "returns a warning when a newer version could be used" do
      @dependency.version_used = "1.0.0"

      dependency_inspector.update_status(@dependency)
      @dependency.status.should == :'warning-req'
    end

    it "returns an error for missing version on Chef Server" do
      @dependency.chef_versions = []
      @dependency.latest_chef = nil

      dependency_inspector.update_status(@dependency)
      @dependency.chef_status.should == :'error-chef'
    end

    it "returns a warning when a newer version exists on the Repository Manager" do
      @dependency.chef_versions = ["1.0.0"]
      @dependency.latest_chef = Solve::Version.new("1.0.0")

      dependency_inspector.update_status(@dependency)
      @dependency.chef_status.should == :'warning-chef'
    end

    it "returns an error for missing version on the Repository Manager" do
      @dependency.repomanager_tags = []
      @dependency.latest_metadata_repomanager = nil

      dependency_inspector.update_status(@dependency)
      @dependency.repomanager_status.should == :'error-repomanager'
    end

    it "returns a warning when a newer version exists on Chef Server" do
      @dependency.repomanager_tags = ["1.0.0"]
      @dependency.latest_metadata_repomanager = Solve::Version.new("1.0.0")
      @dependency.latest_tag_repomanager = Solve::Version.new("1.0.0")

      dependency_inspector.update_status(@dependency)
      @dependency.repomanager_status.should == :'warning-outofdate-repomanager'
    end

    it "returns a warning when last tag on Repository Manager doesn't match last metadata's version" do
      @dependency.repomanager_tags = ["1.0.0", "1.0.1"]
      @dependency.latest_metadata_repomanager = Solve::Version.new("1.0.0")

      dependency_inspector.update_status(@dependency)
      @dependency.repomanager_status.should == :'warning-mismatch-repomanager'
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
    it "retrieves versions using a valid project" do
      data = {"cookbooks" =>
        {
          "Test-1.0.1" => {"metadata.rb" => "depends \"mysql\""}
        }
      }
      @chef_server.load_data data

      versions = dependency_inspector.find_chef_server_versions('Test')
      versions.should == ["1.0.1"]
    end

    it "doesn't retrieve any versions using a missing project" do
      versions = dependency_inspector.find_chef_server_versions('Test')
      versions.should == []
    end
  end
end