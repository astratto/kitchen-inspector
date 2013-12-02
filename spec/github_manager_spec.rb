require_relative 'support/spec_helper'

describe GithubManager do
  let(:manager) do
    config = {:type => "Github", :allowed_users => ["astratto"]}

    manager = GithubManager.new config
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
        config = {:type => "Github",
                  :token => ENV['GITHUB_TOKEN'],
                  :allowed_users => ["astratto"]
                }

        manager = GithubManager.new config
        manager
      end
    end

    context "invalid configuration" do
      it "raise an error when users are not configured" do
        config = {:type => "Github",
                  :token => ENV['GITHUB_TOKEN']
                }

        expect{GithubManager.new(config)}.to raise_error(GithubManager::GithubUsersNotConfiguredError)
      end
    end
  end

  describe "#projects_by_name" do
    it "returns the correct project for astratto/kitchen-inspector", :type => :external do
      projects = manager.projects_by_name "kitchen-inspector"
      expect(projects).not_to eq(nil)
    end
  end

  describe "#tags" do
    let(:project) { manager.projects_by_name("kitchen-inspector").first }

    it "returns the correct tags for astratto/kitchen-inspector", :type => :external do

      expect(manager.tags(project)).to eq(
            {"1.0.1" => "b935719a532c8042b51de560db09881803fbb511",
             "1.0.0" => "0ab566a390b864e1ba844d06b4195d52a6f0975c"})
    end
  end

  describe "#project_metadata" do
    let(:project) { manager.projects_by_name("cook-test").first }
    it "returns the correct metadata for github.com/astratto/cook-test v.1.0.0", :type => :external do

      metadata = manager.project_metadata(project, "689dcf42e0cc0710fd337ebd1fee3d2ee8e7dca4")
      expect(metadata.name).to eq("cook-test")
    end

    it "returns the correct version for github.com/astratto/cook-test v.1.0.0", :type => :external do
      version = manager.project_metadata_version(project, "689dcf42e0cc0710fd337ebd1fee3d2ee8e7dca4")
      expect(version).to eq("1.0.0")
    end

    it "returns the correct dependencies for github.com/astratto/cook-test v.1.0.0", :type => :external do
      dependencies = manager.project_dependencies(project, "689dcf42e0cc0710fd337ebd1fee3d2ee8e7dca4")

      expect(dependencies.collect(&:name)).to eq(["openssl", "build-essential"])
    end
  end
end