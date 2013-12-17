require_relative 'support/spec_helper'

describe GitLabManager do
  describe "API" do
    let(:manager) do
      config = {:base_url => "Test url",
          :token => "token",
          :type => "GitLab"
        }

      manager = GitLabManager.new config
      manager
    end

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
        config = {:base_url => "Test url",
                  :token => "token",
                  :type => "GitLab"
                }

        manager = GitLabManager.new config
        manager
      end
    end

    context "invalid configuration" do
      it "raises an error when GitLab Token is not configured" do
        config = {:base_url => "Test url",
                  :type => "GitLab"
                }

        expect do
          GitLabManager.new config
        end.to raise_error(GitLabAccessNotConfiguredError)
      end

      it "raises an error when GitLab Base Url is not configured" do
        config = {:token => "token",
                  :type => "GitLab"
                }

        expect do
          GitLabManager.new config
        end.to raise_error(GitLabAccessNotConfiguredError)
      end
    end
  end
end
