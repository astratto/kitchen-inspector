require_relative 'support/spec_helper'

describe Inspector::Report do
  let(:dependency_inspector) { generate_dependency_inspector }

  describe "generate" do
    describe "single dependency" do
      before(:each) do
        dep1 = Inspector::Dependency.new("Test", "~> 1.0.0")
        dep1.chef_versions = ["1.0.0", "1.0.1"]
        dep1.repomanager_tags = ["1.0.0", "1.0.1"]
        dep1.latest_metadata_repomanager = Solve::Version.new("1.0.1")
        dep1.latest_tag_repomanager = Solve::Version.new("1.0.1")
        dep1.latest_chef = Solve::Version.new("1.0.1")
        dep1.version_used = "1.0.1"

        dependency_inspector.update_status(dep1)

        @dependencies = [dep1]
      end

      it "yields a global up-to-date" do
        output, code = Inspector::Report.generate(@dependencies, 'table', {})
        output.split("\n").grep(/Test|Status:/).join("\n").should == \
        "| Test | ~> 1.0.0    | 1.0.1 | 1.0.1  | 1.0.1      |      #{Inspector::TICK_MARK.green}      |      #{Inspector::TICK_MARK.green}      |     #{Inspector::TICK_MARK.green}      |\n" \
        "#{'Status: up-to-date (%s)'.green}" % Inspector::TICK_MARK
        code.should == :'up-to-date'
      end

      it "yields a global error-repomanager" do
        dep1 = @dependencies.first
        dep1.repomanager_tags = []
        dep1.latest_metadata_repomanager = nil
        dep1.latest_tag_repomanager = nil
        dependency_inspector.update_status(dep1)

        output, code = Inspector::Report.generate(@dependencies, 'table', {})
        output.split("\n").grep(/Test|Status:/).join("\n").should == \
        "| Test | ~> 1.0.0    | 1.0.1 | 1.0.1  |            |      #{Inspector::TICK_MARK.green}      |      #{Inspector::TICK_MARK.green}      |     #{Inspector::X_MARK.red}      |\n" \
        "#{'Status: error-repomanager (%s)'.yellow}" % Inspector::X_MARK
        code.should == :'error-repomanager'
      end

      it "yields a global warning-mismatch-repomanager" do
        dep1 = @dependencies.first
        dep1.repomanager_tags = ["1.0.0"]
        dep1.latest_metadata_repomanager = Solve::Version.new("1.0.0")
        dep1.latest_tag_repomanager = Solve::Version.new("1.0.1")
        dependency_inspector.update_status(dep1)

        output, code = Inspector::Report.generate(@dependencies, 'table', {})
        output.split("\n").grep(/Test|Status:/).join("\n").should == \
        "| Test | ~> 1.0.0    | 1.0.1 | 1.0.1  | 1.0.0      |      #{Inspector::TICK_MARK.green}      |      #{Inspector::TICK_MARK.green}      |     #{Inspector::ESCLAMATION_MARK.bold.light_red}      |\n" \
        "#{'Status: warning-mismatch-repomanager (!)'.light_red}"
        code.should == :'warning-mismatch-repomanager'
      end

      it "yields a global warning-outofdate-repomanager" do
        dep1 = @dependencies.first
        dep1.repomanager_tags = ["1.0.0"]
        dep1.latest_metadata_repomanager = Solve::Version.new("1.0.0")
        dep1.latest_tag_repomanager = Solve::Version.new("1.0.0")
        dependency_inspector.update_status(dep1)

        output, code = Inspector::Report.generate(@dependencies, 'table', {})
        output.split("\n").grep(/Test|Status:/).join("\n").should == \
        "| Test | ~> 1.0.0    | 1.0.1 | 1.0.1  | 1.0.0      |      #{Inspector::TICK_MARK.green}      |      #{Inspector::TICK_MARK.green}      |     #{(Inspector::ESCLAMATION_MARK * 2).bold.light_red}     |\n" \
        "#{'Status: warning-outofdate-repomanager (!!)'.light_red}"
        code.should == :'warning-outofdate-repomanager'
      end

      it "yields a global warning-chef" do
        dep1 = @dependencies.first
        dep1.chef_versions = ["1.0.0"]
        dep1.latest_chef = Solve::Version.new("1.0.0")
        dep1.version_used = "1.0.0"
        dependency_inspector.update_status(dep1)

        output, code = Inspector::Report.generate(@dependencies, 'table', {})
        output.split("\n").grep(/Test|Status:/).join("\n").should == \
        "| Test | ~> 1.0.0    | 1.0.0 | 1.0.0  | 1.0.1      |      #{Inspector::TICK_MARK.green}      |      #{Inspector::INFO_MARK.bold.blue}      |     #{Inspector::TICK_MARK.green}      |\n" \
        "#{'Status: warning-chef (i)'.blue}"
        code.should == :'warning-chef'
      end

      it "yields a global warning-req" do
        dep1 = Inspector::Dependency.new("Test", "= 1.0.0")
        dep1.chef_versions = ["1.0.0", "1.0.1"]
        dep1.repomanager_tags = ["1.0.0", "1.0.1"]
        dep1.latest_metadata_repomanager = Solve::Version.new("1.0.1")
        dep1.latest_tag_repomanager = Solve::Version.new("1.0.1")
        dep1.latest_chef = Solve::Version.new("1.0.1")
        dep1.version_used = "1.0.0"
        dependency_inspector.update_status(dep1)

        output, code = Inspector::Report.generate([dep1], 'table', {})
        output.split("\n").grep(/Test|Status:/).join("\n").should == \
        "| Test | = 1.0.0     | 1.0.0 | 1.0.1  | 1.0.1      |      #{Inspector::ESCLAMATION_MARK.bold.yellow}      |      #{Inspector::TICK_MARK.green}      |     #{Inspector::TICK_MARK.green}      |\n" \
        "#{'Status: warning-req (!)'.yellow}"
        code.should == :'warning-req'
      end

      it "yields a global error due to wrong metadata" do
        dep1 = Inspector::Dependency.new("Test", "~> 1.0.0")
        dep1.chef_versions = ["1.1.0"]
        dep1.repomanager_tags = ["1.1.0"]
        dep1.latest_metadata_repomanager = Solve::Version.new("1.1.0")
        dep1.latest_tag_repomanager = Solve::Version.new("1.1.0")
        dep1.latest_chef = Solve::Version.new("1.1.0")
        dep1.version_used = nil
        dependency_inspector.update_status(dep1)

        output, code = Inspector::Report.generate([dep1], 'table', {})
        output.split("\n").grep(/Test|Status:/).join("\n").should == \
        "| #{'Test'.red} | ~> 1.0.0    |      | 1.1.0  | 1.1.0      |      #{Inspector::X_MARK.red}      |      #{Inspector::TICK_MARK.green}      |     #{Inspector::TICK_MARK.green}      |\n" \
        "#{'Status: error (%s)'.red}" % Inspector::X_MARK
        code.should == :'error'
      end

      it "yields a global error due to Chef Server" do
        dep1 = @dependencies.first
        dep1.chef_versions = []
        dep1.latest_chef = nil
        dep1.version_used = nil
        dependency_inspector.update_status(dep1)

        output, code = Inspector::Report.generate([dep1], 'table', {})
        output.split("\n").grep(/Test|Status:/).join("\n").should == \
        "| #{'Test'.red} | ~> 1.0.0    |      |        | 1.0.1      |      #{Inspector::X_MARK.red}      |      #{Inspector::X_MARK.red}      |     #{Inspector::TICK_MARK.green}      |\n" \
        "#{'Status: error (%s)'.red}" % Inspector::X_MARK
        code.should == :'error'
      end
    end
  end
end
