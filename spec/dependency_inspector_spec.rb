require_relative 'support/spec_helper'

describe DependencyInspector do
  let(:dependency_inspector) { generate_dependency_inspector }

  let(:repomanager_info) do
    {:tags =>{"1.0.0" => "a", "1.0.1" => "b"},
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

      it "raises an error if an unsupported field is specified" do
          config = StringIO.new
          config.puts "repository_manager :type => 'Gitlab', :base_url => 'http://localhost:8080', :token =>'test_token'"
          config.puts "chef_server_url 'http://localhost:4000'"
          config.puts "chef_client_pem 'testclient.pem'"
          config.puts "chef_username 'test_user'"
          config.puts "invalid_field 'test'"

          expect do
            DependencyInspector.new config
          end.to raise_error(ConfigurationError)
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
      expect(@dep.repomanager[:status]).to eq(:up_to_date)
      expect(@dep.chef[:status]).to eq(:up_to_date)
      expect(@dep.status).to eq(:up_to_date)
    end

    context "error statuses" do
      it "when a valid version cannot be found" do
        chef = {:version_used => nil}

        dependency_inspector.update_dependency(@dep, chef, repomanager_info)
        expect(@dep.status).to eq(:err)
      end

      it "missing version on Chef Server" do
        chef = {:versions => [],
                :latest_version => nil}

        dependency_inspector.update_dependency(@dep, chef, repomanager_info)
        expect(@dep.chef[:status]).to eq(:err_chef)
      end

      it "missing version on the Repository Manager" do
        repomanager = {:tags =>[],
                       :latest_metadata => nil}


        dependency_inspector.update_dependency(@dep, chef_info, repomanager)
        expect(@dep.repomanager[:status]).to eq(:err_repo)
      end
    end

    context "warning statuses" do
      it "a newer version could be used" do
        chef_info[:version_used] = "1.0.0"

        dependency_inspector.update_dependency(@dep, chef_info, repomanager_info)
        expect(@dep.status).to eq(:warn_req)
      end

      it "a newer version exists on the Repository Manager" do
        chef_info = {:versions => ["1.0.0"],
                     :latest_version => Solve::Version.new("1.0.0")}

        dependency_inspector.update_dependency(@dep, chef_info, repomanager_info)
        expect(@dep.chef[:status]).to eq(:warn_chef)
      end

      it "a newer version exists on Chef Server" do
        repomanager_info = {:tags => {"1.0.0" => "a"},
                            :latest_metadata => Solve::Version.new("1.0.0"),
                            :latest_tag => Solve::Version.new("1.0.0")}

        dependency_inspector.update_dependency(@dep, chef_info, repomanager_info)
        expect(@dep.repomanager[:status]).to eq(:warn_outofdate_repo)
      end

      it "last tag on Repository Manager doesn't match last metadata's version" do
        repomanager = {:tags =>{"1.0.0" => "a", "1.0.1" => "b"},
                       :latest_metadata => Solve::Version.new("1.0.0"),
                       :latest_tag => Solve::Version.new("1.0.1")}

        dependency_inspector.update_dependency(@dep, chef_info, repomanager)
        expect(@dep.repomanager[:status]).to eq(:warn_mismatch_repo)
      end

      it "warns when project is not unique on Repository Manager" do
        repomanager = {:tags =>{"1.0.0" => "a", "1.0.1" => "b"},
                       :latest_metadata => Solve::Version.new("1.0.1"),
                       :latest_tag => Solve::Version.new("1.0.1"),
                       :not_unique => true
                     }

        dependency_inspector.update_dependency(@dep, chef_info, repomanager)
        expect(@dep.repomanager[:status]).to eq(:warn_notunique_repo)
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
          "test-1.0.1" => {"metadata.rb" => "depends \"mysql\""}
        }
      }
      @chef_server.load_data data

      versions = dependency_inspector.find_chef_server_versions('test')
      expect(versions).to eq(["1.0.1"])
    end

    it "doesn't retrieve any versions using a missing project" do
      versions = dependency_inspector.find_chef_server_versions('test')
      expect(versions).to eq([])
    end
  end

  describe "#investigate" do
    before(:each) do
      GitlabManager.any_instance.stub(:projects_by_name).and_return([])

      data = {"cookbooks" =>
        {
          "test-1.0.1" => {"metadata.rb" => "depends \"dep1 ~> 1.0.0\""},
          "dep1-1.0.0" => {"metadata.rb" => "depends \"dep2 ~> 1.0.0\""},
          "dep2-1.0.0" => {"metadata.rb" => ""},
        }
      }
      @chef_server.load_data data
    end

    context "dependencies on Chef Server but not on Repository Manager" do
      it "doesn't fail" do
        dependencies = dependency_inspector.investigate("#{File.dirname(__FILE__)}/data/cookbook_deps")
        expect(dependencies.count).to eq(2)
        expect(dependencies.first.repomanager).not_to be_nil
      end

      it "sets correct remarks" do
        dependencies = dependency_inspector.investigate("#{File.dirname(__FILE__)}/data/cookbook_deps")
        expect(dependencies.first.remarks).to eq(["Gitlab doesn't contain any versions."])
      end

      it "sets correct chef info" do
        dependencies = dependency_inspector.investigate("#{File.dirname(__FILE__)}/data/cookbook_deps")
        dep1 = dependencies.first

        expect(dep1.chef).not_to be_empty
        expect(dep1.chef[:versions]).to eq(["1.0.1"])
        expect(dep1.chef[:latest_version]).to eq(Solve::Version.new("1.0.1"))
        expect(dep1.chef[:version_used]).to eq("1.0.1")
      end
    end

    context "dependencies on Repository Manager" do
      before(:each) do
        project = double()

        allow(project).to receive(:id).and_return(1)
        allow(project).to receive(:path_with_namespace).and_return("group/project")

        GitlabManager.any_instance.stub(:projects_by_name).and_return([
          project
        ])

        GitlabManager.any_instance.stub(:tags).with(project).and_return(
          { "1.0.1" => "fake_sha1" }
        )

        GitlabManager.any_instance.stub(:project_metadata_version).with(project, "fake_sha1").and_return(
          "1.0.1"
        )
      end

      it "sets correct repomanager info without recursing" do
        dependencies = dependency_inspector.investigate("#{File.dirname(__FILE__)}/data/cookbook_deps", recursive=false)
        dep1 = dependencies.first

        expect(dependencies.count).to eq(2)
        expect(dep1.repomanager).not_to be_nil
        expect(dep1.repomanager[:tags]).to eq({"1.0.1"=>"fake_sha1"})
        expect(dep1.repomanager[:latest_metadata]).to eq(Solve::Version.new("1.0.1"))
        expect(dep1.repomanager[:latest_tag]).to eq(Solve::Version.new("1.0.1"))
        expect(dep1.repomanager[:source_url]).to eq("http://localhost:8080/group/project")
      end
    end
  end
end