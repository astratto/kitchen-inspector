require_relative 'support/spec_helper'

describe Inspector::GitlabManager do
  describe "API" do
    let(:manager) do
      config = {:base_url => "Test url",
          :token => "token",
          :type => "Gitlab"
        }

      manager = Inspector::GitlabManager.new config
      manager
    end

    [:retrieve_dependencies, :versions, :source_url, :project_by_name].each do |method|
      it "responds to #{method}" do
        manager.respond_to?(method).should be_true
      end
    end
  end

  describe "#initialize" do
    it "creates a valid Manager with a full configuration" do
      config = {:base_url => "Test url",
                :token => "token",
                :type => "Gitlab"
              }

      manager = Inspector::GitlabManager.new config
      manager
    end

    it "raises an error when Gitlab Token is not configured" do
      config = {:base_url => "Test url",
                :type => "Gitlab"
              }

      expect do
        Inspector::GitlabManager.new config
      end.to raise_error(Inspector::GitlabAccessNotConfiguredError)
    end

    it "raises an error when Gitlab Base Url is not configured" do
      config = {:token => "token",
                :type => "Gitlab"
              }

      expect do
        Inspector::GitlabManager.new config
      end.to raise_error(Inspector::GitlabAccessNotConfiguredError)
    end
  end
end