require_relative 'support/spec_helper'

describe GitlabManager do
  describe "API" do
    let(:manager) do
      config = {:base_url => "Test url",
          :token => "token",
          :type => "Gitlab"
        }

      manager = GitlabManager.new config
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
                  :type => "Gitlab"
                }

        manager = GitlabManager.new config
        manager
      end
    end

    context "invalid configuration" do
      it "raises an error when Gitlab Token is not configured" do
        config = {:base_url => "Test url",
                  :type => "Gitlab"
                }

        expect do
          GitlabManager.new config
        end.to raise_error(GitlabAccessNotConfiguredError)
      end

      it "raises an error when Gitlab Base Url is not configured" do
        config = {:token => "token",
                  :type => "Gitlab"
                }

        expect do
          GitlabManager.new config
        end.to raise_error(GitlabAccessNotConfiguredError)
      end
    end
  end
end
