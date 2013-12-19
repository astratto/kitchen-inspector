require_relative 'support/spec_helper'

describe HealthBureau do
  before(:each) do
    # Ignore existing knife.rb configuration
    orig_file = File.method(:exists?)
    File.stub(:exists?).with(anything()) { |*args| orig_file.call(*args) }
    File.stub(:exists?).with("#{Dir.home}/.chef/knife.rb").and_return(false)
  end

  let(:health_bureau) { generate_health_bureau }

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
    context "Incomplete configuration" do
      it "raises an error if a Repository Manager is not configured" do
          config = StringIO.new
          config.puts "chef_server :url => 'http://localhost:4000', :client_pem => 'testclient.pem', :username => 'test_user'"

          expect do
            HealthBureau.new config
          end.to raise_error(ConfigurationError, "Repository Manager is not configured properly, "\
                                                 "please check your 'repository_manager' configuration.")
      end

      it "raises an error if a Chef Server is not configured" do
          config = StringIO.new
          config.puts "repository_manager :type => 'GitLab', :base_url => 'http://localhost:8080', :token =>'test_token'"

          expect do
            HealthBureau.new config
          end.to raise_error(ConfigurationError, "Chef Server is not configured properly, "\
                                                 "please check your 'chef_server' configuration.")
      end
    end

    context "Repository Manager" do
      it "raises an error if an unsupported Repository Manager is specified" do
          config = StringIO.new
          config.puts "repository_manager :type => 'Unknown', :base_url => 'http://localhost:8080', :token =>'test_token'"
          config.puts "chef_server :url => 'http://localhost:4000', :client_pem => 'testclient.pem', :username => 'test_user'"

          expect do
            HealthBureau.new config
          end.to raise_error(RepositoryManagerError, "Repository Manager 'Unknown' not supported.")
      end

      it "raises an error if an unsupported field is specified" do
          config = StringIO.new
          config.puts "repository_manager :type => 'GitLab', :base_url => 'http://localhost:8080', :token =>'test_token'"
          config.puts "chef_server :url => 'http://localhost:4000', :client_pem => 'testclient.pem', :username => 'test_user'"
          config.puts "invalid_field 'test'"

          expect do
            HealthBureau.new config
          end.to raise_error(ConfigurationError, "Unsupported configuration: invalid_field.")
      end

      context "GitLab" do
        context "with a full configuration" do
          it "creates a valid Inspector" do
            config = StringIO.new
            config.puts "repository_manager :type => 'GitLab', :base_url => 'http://localhost:8080', :token =>'test_token'"
            config.puts "chef_server :url => 'http://localhost:4000', :client_pem => 'testclient.pem', :username => 'test_user'"

            inspector = HealthBureau.new config
            inspector
          end
        end

        context "with invalid configuration" do
          it "raises an error when GitLab Token is not configured" do
            config = StringIO.new
            config.puts "repository_manager :type => 'GitLab', :base_url => 'http://localhost:8080'"
            config.puts "chef_server :url => 'http://localhost:4000', :client_pem => 'testclient.pem', :username => 'test_user'"

            expect do
              HealthBureau.new config
            end.to raise_error(GitLabAccessNotConfiguredError, "GitLab Private Token not configured. " \
                                                               "Please set token in your config file.")
          end

          it "raises an error when GitLab Base Url is not configured" do
            config = StringIO.new
            config.puts "repository_manager :type => 'GitLab', :token =>'test_token'"
            config.puts "chef_server :url => 'http://localhost:4000', :client_pem => 'testclient.pem', :username => 'test_user'"

            expect do
              HealthBureau.new config
            end.to raise_error(GitLabAccessNotConfiguredError, "GitLab base url not configured. " \
                                                               "Please set base_url in your config file.")
          end
        end
      end
    end

    context "Chef Server" do
      it "raises an error when Server Url is not configured" do
        config = StringIO.new
        config.puts "repository_manager :type => 'GitLab', :base_url => 'http://localhost:8080', :token =>'test_token'"
        config.puts "chef_server :client_pem => 'testclient.pem', :username => 'test_user'"

        expect do
          HealthBureau.new config
        end.to raise_error(ChefAccessNotConfiguredError, "Chef Server url not configured. " \
                                                         "Please set :url in your config file.")
      end

      it "raises an error when Client PEM is not configured" do
        config = StringIO.new
        config.puts "repository_manager :type => 'GitLab', :base_url => 'http://localhost:8080', :token =>'test_token'"
        config.puts "chef_server :url => 'http://localhost:4000', :username => 'test_user'"

        expect do
          HealthBureau.new config
        end.to raise_error(ChefAccessNotConfiguredError, "Chef client PEM not configured. " \
                                                         "Please set :client_pem in your config file.")
      end

      it "raises an error when Username is not configured" do
        config = StringIO.new
        config.puts "repository_manager :type => 'GitLab', :base_url => 'http://localhost:8080', :token =>'test_token'"
        config.puts "chef_server :url => 'http://localhost:4000', :client_pem => 'testclient.pem'"

        expect do
          HealthBureau.new config
        end.to raise_error(ChefAccessNotConfiguredError, "Chef username not configured. " \
                                                         "Please set :username in your config file.")
      end
    end
  end

  describe "#update_dependency" do
    before(:each) do
      @dep = Dependency.new("test", ">= 0")
    end

    it "returns a success for correct versions on both servers" do
      health_bureau.update_dependency(@dep, chef_info, repomanager_info)
      expect(@dep.repomanager[:status]).to eq(:up_to_date)
      expect(@dep.chef[:status]).to eq(:up_to_date)
      expect(@dep.status).to eq(:up_to_date)
    end

    context "error statuses" do
      it "when a valid version cannot be found" do
        chef = {:version_used => nil}

        health_bureau.update_dependency(@dep, chef, repomanager_info)
        expect(@dep.status).to eq(:err_req)
      end

      it "missing version on Chef Server" do
        chef = {:versions => [],
                :latest_version => nil}

        health_bureau.update_dependency(@dep, chef, repomanager_info)
        expect(@dep.chef[:status]).to eq(:err_chef)
      end

      it "missing version on the Repository Manager" do
        repomanager = {:tags =>[],
                       :latest_metadata => nil}


        health_bureau.update_dependency(@dep, chef_info, repomanager)
        expect(@dep.repomanager[:status]).to eq(:err_repo)
      end
    end

    context "warning statuses" do
      it "a newer version could be used" do
        chef_info[:version_used] = "1.0.0"

        health_bureau.update_dependency(@dep, chef_info, repomanager_info)
        expect(@dep.status).to eq(:warn_req)
      end

      it "a newer version exists on the Repository Manager" do
        chef_info = {:versions => ["1.0.0"],
                     :latest_version => Solve::Version.new("1.0.0")}

        health_bureau.update_dependency(@dep, chef_info, repomanager_info)
        expect(@dep.chef[:status]).to eq(:warn_chef)
      end

      it "a newer version exists on Chef Server" do
        repomanager_info = {:tags => {"1.0.0" => "a"},
                            :latest_metadata => Solve::Version.new("1.0.0"),
                            :latest_tag => Solve::Version.new("1.0.0")}

        health_bureau.update_dependency(@dep, chef_info, repomanager_info)
        expect(@dep.repomanager[:status]).to eq(:warn_outofdate_repo)
      end

      it "last tag on Repository Manager doesn't match last metadata's version" do
        repomanager = {:tags =>{"1.0.0" => "a", "1.0.1" => "b"},
                       :latest_metadata => Solve::Version.new("1.0.0"),
                       :latest_tag => Solve::Version.new("1.0.1")}

        health_bureau.update_dependency(@dep, chef_info, repomanager)
        expect(@dep.repomanager[:status]).to eq(:warn_mismatch_repo)
      end

      it "warns when project is not unique on Repository Manager" do
        repomanager = {:tags =>{"1.0.0" => "a", "1.0.1" => "b"},
                       :latest_metadata => Solve::Version.new("1.0.1"),
                       :latest_tag => Solve::Version.new("1.0.1"),
                       :not_unique => true
                     }

        health_bureau.update_dependency(@dep, chef_info, repomanager)
        expect(@dep.repomanager[:status]).to eq(:warn_notunique_repo)
      end
    end
  end

  describe "#satisfy" do
    it "returns the correct version when existing" do
      version = health_bureau.satisfy("~> 1.0.1", ["1.0.0", "1.0.1"])
      expect(version).to eq("1.0.1")
    end

    it "returns nil when a satisfying version doesn't exist" do
      version = health_bureau.satisfy("~> 1.0.1", ["1.0.0"])
      expect(version).to eq(nil)
    end
  end

  describe "#find_versions" do
    it "retrieves versions using a valid project" do
      data = {"cookbooks" =>
        {
          "test-1.0.1" => {"metadata.rb" => "depends \"mysql\""}
        }
      }
      @chef_server.load_data data

      versions = health_bureau.chef_inspector.find_versions('test')
      expect(versions).to eq(["1.0.1"])
    end

    it "doesn't retrieve any versions using a missing project" do
      versions = health_bureau.chef_inspector.find_versions('test')
      expect(versions).to eq([])
    end
  end

  describe "#investigate" do
    before(:each) do
      GitLabManager.any_instance.stub(:projects_by_name).and_return([])

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
        dependencies = health_bureau.investigate("#{File.dirname(__FILE__)}/data/cookbook_deps")
        expect(dependencies.count).to eq(2)
        expect(dependencies.first.repomanager).not_to be_nil
      end

      it "sets correct remarks" do
        dependencies = health_bureau.investigate("#{File.dirname(__FILE__)}/data/cookbook_deps")
        expect(dependencies.first.remarks).to eq(["GitLab doesn't contain any versions."])
      end

      it "sets correct chef info" do
        dependencies = health_bureau.investigate("#{File.dirname(__FILE__)}/data/cookbook_deps")
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

        GitLabManager.any_instance.stub(:projects_by_name).and_return([
          project
        ])

        GitLabManager.any_instance.stub(:tags).with(project).and_return(
          { "1.0.1" => "fake_sha1" }
        )

        GitLabManager.any_instance.stub(:project_metadata_version).with(project, "fake_sha1").and_return(
          "1.0.1"
        )
      end

      it "sets correct repomanager info without recursing" do
        dependencies = health_bureau.investigate("#{File.dirname(__FILE__)}/data/cookbook_deps", recursive=false)
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