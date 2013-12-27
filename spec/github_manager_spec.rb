require_relative 'support/spec_helper'

describe GitHubManager do
  let(:manager) do
    config = {:type => "GitHub",
              :allowed_users => ["kitchen-inspector"],
              :token => ENV['GITHUB_TOKEN']}

    manager = GitHubManager.new config
    manager
  end

  context "API" do
    [:project_dependencies, :tags, :source_url, :projects_by_name,
     :project_metadata, :project_metadata_version].each do |method|
      it "responds to #{method}" do
        expect(manager.respond_to?(method)).to be_true
      end
    end
  end

  describe "#initialize" do
    context "full configuration" do
      it "creates a valid Manager" do
        config = {:type => "GitHub",
                  :token => ENV['GITHUB_TOKEN'],
                  :allowed_users => ["kitchen-inspector"]
                }

        manager = GitHubManager.new config
        manager
      end
    end

    context "invalid configuration" do
      it "raise an error when users are not configured" do
        config = {:type => "GitHub",
                  :token => ENV['GITHUB_TOKEN']
                }

        expect{GitHubManager.new(config)}.to raise_error(GitHubManager::GitHubUsersNotConfiguredError)
      end
    end
  end

  describe "#projects_by_name" do
    it "returns the correct project for kitchen-inspector/cook-test", :type => :external do
      projects = manager.projects_by_name "cook-test"
      expect(projects).not_to eq(nil)
    end
  end

  describe "#tags" do
    let(:project) { manager.projects_by_name("cook-test").first }

    it "returns the correct tags for kitchen-inspector/cook-test", :type => :external do
      expect(manager.tags(project)["1.1.0"]).to eq("5c430684e34415df07f3178dff96f2cf23a59452")
    end
  end

  describe "#project_metadata" do
    let(:project) { manager.projects_by_name("cook-test").first }
    it "returns the correct metadata for github.com/kitchen-inspector/cook-test v.1.1.0", :type => :external do

      metadata = manager.project_metadata(project, "5c430684e34415df07f3178dff96f2cf23a59452")
      expect(metadata.name).to eq("cook-test")
    end

    it "returns the correct version for github.com/kitchen-inspector/cook-test v.1.1.0", :type => :external do
      version = manager.project_metadata_version(project, "5c430684e34415df07f3178dff96f2cf23a59452")
      expect(version).to eq("1.1.0")
    end

    it "returns the correct dependencies for github.com/kitchen-inspector/cook-test v.1.1.0", :type => :external do
      dependencies = manager.project_dependencies(project, "5c430684e34415df07f3178dff96f2cf23a59452")

      expect(dependencies.collect(&:name)).to eq(["openssl", "build-essential"])
    end
  end
end