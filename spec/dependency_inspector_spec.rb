require_relative 'support/spec_helper'

describe DependencyInspector do
  let(:dependency_inspector) { generate_dependency_inspector }

  let(:repomanager_info) do
    {:tags =>["1.0.0", "1.0.1"],
     :latest_metadata => Solve::Version.new("1.0.1"),
     :latest_tag => Solve::Version.new("1.0.1")}
  end

  let(:chef_info) do
    {:latest_version => Solve::Version.new("1.0.1"),
     :version_used => "1.0.1",
     :versions => ["1.0.0", "1.0.1"]}
  end

  describe "#initialize" do
    context "Repository Manager" do
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

      context "Gitlab" do
        context "with a full configuration" do
          it "creates a valid Inspector" do
            config = StringIO.new
            config.puts "repository_manager :type => 'Gitlab', :base_url => 'http://localhost:8080', :token =>'test_token'"
            config.puts "chef_server_url 'http://localhost:4000'"
            config.puts "chef_client_pem 'testclient.pem'"
            config.puts "chef_username 'test_user'"

            inspector = DependencyInspector.new config
            inspector
          end
        end

        context "with invalid configuration" do
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
    end

    context "Chef Server" do
      it "raises an error when Server Url is not configured" do
        config = StringIO.new
        config.puts "repository_manager :type => 'Gitlab', :base_url => 'http://localhost:8080', :token =>'test_token'"
        config.puts "chef_client_pem 'testclient.pem'"
        config.puts "chef_username 'test_user'"

        expect do
          DependencyInspector.new config
        end.to raise_error(ChefAccessNotConfiguredError)
      end

      it "raises an error when Client PEM is not configured" do
        config = StringIO.new
        config.puts "repository_manager :type => 'Gitlab', :base_url => 'http://localhost:8080', :token =>'test_token'"
        config.puts "chef_server_url 'http://localhost:4000'"
        config.puts "chef_username 'test_user'"

        expect do
          DependencyInspector.new config
        end.to raise_error(ChefAccessNotConfiguredError)
      end

      it "raises an error when Username is not configured" do
        config = StringIO.new
        config.puts "repository_manager :type => 'Gitlab', :base_url => 'http://localhost:8080', :token =>'test_token'"
        config.puts "chef_server_url 'http://localhost:4000'"
        config.puts "chef_client_pem 'testclient.pem'"

        expect do
          DependencyInspector.new config
        end.to raise_error(ChefAccessNotConfiguredError)
      end
    end
  end

  describe "#update_dependency" do
    before(:each) do
      @dep = Dependency.new("test", ">= 0")
    end

    it "returns a success for correct versions on both servers" do
      dependency_inspector.update_dependency(@dep, chef_info, repomanager_info)
      expect(@dep.repomanager[:status]).to eq(:'up-to-date')
      expect(@dep.chef[:status]).to eq(:'up-to-date')
      expect(@dep.status).to eq(:'up-to-date')
    end

    context "error statuses" do
      it "when a valid version cannot be found" do
        chef = {:version_used => nil}

        dependency_inspector.update_dependency(@dep, chef, repomanager_info)
        expect(@dep.status).to eq(:error)
      end

      it "missing version on Chef Server" do
        chef = {:versions => [],
                :latest_version => nil}

        dependency_inspector.update_dependency(@dep, chef, repomanager_info)
        expect(@dep.chef[:status]).to eq(:'error-chef')
      end

      it "missing version on the Repository Manager" do
        repomanager = {:tags =>[],
                       :latest_metadata => nil}


        dependency_inspector.update_dependency(@dep, chef_info, repomanager)
        expect(@dep.repomanager[:status]).to eq(:'error-repomanager')
      end
    end

    context "warning statuses" do
      it "a newer version could be used" do
        chef_info[:version_used] = "1.0.0"

        dependency_inspector.update_dependency(@dep, chef_info, repomanager_info)
        expect(@dep.status).to eq(:'warning-req')
      end

      it "a newer version exists on the Repository Manager" do
        chef_info = {:versions => ["1.0.0"],
                     :latest_version => Solve::Version.new("1.0.0")}

        dependency_inspector.update_dependency(@dep, chef_info, repomanager_info)
        expect(@dep.chef[:status]).to eq(:'warning-chef')
      end

      it "a newer version exists on Chef Server" do
        repomanager_info = {:tags => ["1.0.0"],
                            :latest_metadata => Solve::Version.new("1.0.0"),
                            :latest_tag => Solve::Version.new("1.0.0")}

        dependency_inspector.update_dependency(@dep, chef_info, repomanager_info)
        expect(@dep.repomanager[:status]).to eq(:'warning-outofdate-repomanager')
      end

      it "last tag on Repository Manager doesn't match last metadata's version" do
        repomanager = {:tags =>["1.0.0", "1.0.1"],
                       :latest_metadata => Solve::Version.new("1.0.0"),
                       :latest_tag => Solve::Version.new("1.0.1")}

        dependency_inspector.update_dependency(@dep, chef_info, repomanager)
        expect(@dep.repomanager[:status]).to eq(:'warning-mismatch-repomanager')
      end
    end
  end

  describe "#satisfy" do
    it "returns the correct version when existing" do
      version = dependency_inspector.satisfy("~> 1.0.1", ["1.0.0", "1.0.1"])
      expect(version).to eq("1.0.1")
    end

    it "returns nil when a satisfying version doesn't exist" do
      version = dependency_inspector.satisfy("~> 1.0.1", ["1.0.0"])
      expect(version).to eq(nil)
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
      expect(versions).to eq(["1.0.1"])
    end

    it "doesn't retrieve any versions using a missing project" do
      versions = dependency_inspector.find_chef_server_versions('Test')
      expect(versions).to eq([])
    end
  end
end