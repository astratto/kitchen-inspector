require_relative 'support/spec_helper'

describe Report do
  let(:dependency_inspector) { generate_dependency_inspector }

  describe ".generate" do
    context "global status" do
      before(:each) do
        dep1 = Dependency.new("Test", "~> 1.0.0")
        dep1.chef_versions = ["1.0.0", "1.0.1"]
        dep1.repomanager_tags = ["1.0.0", "1.0.1"]
        dep1.latest_metadata_repomanager = Solve::Version.new("1.0.1")
        dep1.latest_tag_repomanager = Solve::Version.new("1.0.1")
        dep1.latest_chef = Solve::Version.new("1.0.1")
        dep1.version_used = "1.0.1"

        dependency_inspector.update_status(dep1)

        @dependencies = [dep1]
      end

      it "up-to-date" do
        output, code = Report.generate(@dependencies, 'table', {})
        expect(output.split("\n").grep(/Test|Status:/).join("\n")).to eq( \
        "| Test | ~> 1.0.0    | 1.0.1 | 1.0.1  | 1.0.1      |      #{TICK_MARK.green}      |      #{TICK_MARK.green}      |     #{TICK_MARK.green}      |\n" \
        "#{'Status: up-to-date (%s)'.green}" % TICK_MARK
        )
        expect(code).to eq(:'up-to-date')
      end

      it "error-repomanager" do
        dep1 = @dependencies.first
        dep1.repomanager_tags = []
        dep1.latest_metadata_repomanager = nil
        dep1.latest_tag_repomanager = nil
        dependency_inspector.update_status(dep1)

        output, code = Report.generate(@dependencies, 'table', {})
        expect(output.split("\n").grep(/Test|Status:/).join("\n")).to eq( \
        "| Test | ~> 1.0.0    | 1.0.1 | 1.0.1  |            |      #{TICK_MARK.green}      |      #{TICK_MARK.green}      |     #{X_MARK.red}      |\n" \
        "#{'Status: error-repomanager (%s)'.yellow}" % X_MARK
        )
        expect(code).to eq(:'error-repomanager')
      end

      it "warning-mismatch-repomanager" do
        dep1 = @dependencies.first
        dep1.repomanager_tags = ["1.0.0"]
        dep1.latest_metadata_repomanager = Solve::Version.new("1.0.0")
        dep1.latest_tag_repomanager = Solve::Version.new("1.0.1")
        dependency_inspector.update_status(dep1)

        output, code = Report.generate(@dependencies, 'table', {})
        expect(output.split("\n").grep(/Test|Status:/).join("\n")).to eq( \
        "| Test | ~> 1.0.0    | 1.0.1 | 1.0.1  | 1.0.0      |      #{TICK_MARK.green}      |      #{TICK_MARK.green}      |     #{ESCLAMATION_MARK.bold.light_red}      |\n" \
        "#{'Status: warning-mismatch-repomanager (!)'.light_red}"
        )
        expect(code).to eq(:'warning-mismatch-repomanager')
      end

      it "warning-outofdate-repomanager" do
        dep1 = @dependencies.first
        dep1.repomanager_tags = ["1.0.0"]
        dep1.latest_metadata_repomanager = Solve::Version.new("1.0.0")
        dep1.latest_tag_repomanager = Solve::Version.new("1.0.0")
        dependency_inspector.update_status(dep1)

        output, code = Report.generate(@dependencies, 'table', {})
        expect(output.split("\n").grep(/Test|Status:/).join("\n")).to eq( \
        "| Test | ~> 1.0.0    | 1.0.1 | 1.0.1  | 1.0.0      |      #{TICK_MARK.green}      |      #{TICK_MARK.green}      |     #{(ESCLAMATION_MARK * 2).bold.light_red}     |\n" \
        "#{'Status: warning-outofdate-repomanager (!!)'.light_red}"
        )
        expect(code).to eq(:'warning-outofdate-repomanager')
      end

      it "warning-chef" do
        dep1 = @dependencies.first
        dep1.chef_versions = ["1.0.0"]
        dep1.latest_chef = Solve::Version.new("1.0.0")
        dep1.version_used = "1.0.0"
        dependency_inspector.update_status(dep1)

        output, code = Report.generate(@dependencies, 'table', {})
        expect(output.split("\n").grep(/Test|Status:/).join("\n")).to eq( \
        "| Test | ~> 1.0.0    | 1.0.0 | 1.0.0  | 1.0.1      |      #{TICK_MARK.green}      |      #{INFO_MARK.bold.blue}      |     #{TICK_MARK.green}      |\n" \
        "#{'Status: warning-chef (i)'.blue}"
        )
        expect(code).to eq(:'warning-chef')
      end

      it "warning-req" do
        dep1 = Dependency.new("Test", "= 1.0.0")
        dep1.chef_versions = ["1.0.0", "1.0.1"]
        dep1.repomanager_tags = ["1.0.0", "1.0.1"]
        dep1.latest_metadata_repomanager = Solve::Version.new("1.0.1")
        dep1.latest_tag_repomanager = Solve::Version.new("1.0.1")
        dep1.latest_chef = Solve::Version.new("1.0.1")
        dep1.version_used = "1.0.0"
        dependency_inspector.update_status(dep1)

        output, code = Report.generate([dep1], 'table', {})
        expect(output.split("\n").grep(/Test|Status:/).join("\n")).to eq( \
        "| Test | = 1.0.0     | 1.0.0 | 1.0.1  | 1.0.1      |      #{ESCLAMATION_MARK.bold.yellow}      |      #{TICK_MARK.green}      |     #{TICK_MARK.green}      |\n" \
        "#{'Status: warning-req (!)'.yellow}"
        )
        expect(code).to eq(:'warning-req')
      end

      it "error due to wrong metadata" do
        dep1 = Dependency.new("Test", "~> 1.0.0")
        dep1.chef_versions = ["1.1.0"]
        dep1.repomanager_tags = ["1.1.0"]
        dep1.latest_metadata_repomanager = Solve::Version.new("1.1.0")
        dep1.latest_tag_repomanager = Solve::Version.new("1.1.0")
        dep1.latest_chef = Solve::Version.new("1.1.0")
        dep1.version_used = nil
        dependency_inspector.update_status(dep1)

        output, code = Report.generate([dep1], 'table', {})
        expect(output.split("\n").grep(/Test|Status:/).join("\n")).to eq( \
        "| #{'Test'.red} | ~> 1.0.0    |      | 1.1.0  | 1.1.0      |      #{X_MARK.red}      |      #{TICK_MARK.green}      |     #{TICK_MARK.green}      |\n" \
        "#{'Status: error (%s)'.red}" % X_MARK
        )
        expect(code).to eq(:'error')
      end

      it "error due to Chef Server" do
        dep1 = @dependencies.first
        dep1.chef_versions = []
        dep1.latest_chef = nil
        dep1.version_used = nil
        dependency_inspector.update_status(dep1)

        output, code = Report.generate([dep1], 'table', {})
        expect(output.split("\n").grep(/Test|Status:/).join("\n")).to eq( \
        "| #{'Test'.red} | ~> 1.0.0    |      |        | 1.0.1      |      #{X_MARK.red}      |      #{X_MARK.red}      |     #{TICK_MARK.green}      |\n" \
        "#{'Status: error (%s)'.red}" % X_MARK
        )
        expect(code).to eq(:'error')
      end

      it "show remarks" do
        dep1 = Dependency.new("Test", "~> 1.0.0")
        dep1.chef_versions = ["1.1.0"]
        dep1.repomanager_tags = ["1.1.0"]
        dep1.latest_metadata_repomanager = Solve::Version.new("1.1.0")
        dep1.latest_tag_repomanager = Solve::Version.new("1.1.0")
        dep1.latest_chef = Solve::Version.new("1.1.0")
        dep1.version_used = nil
        dependency_inspector.update_status(dep1)

        output, code = Report.generate([dep1, dep1], 'table', {:remarks => true})
        expect(output).to eq( \
        "+------+-------------+------+--------+------------+-------------+-------------+------------+---------+\n" \
        "| Name | Requirement | Used | Latest | Latest     | Requirement | Chef Server | Repository | Remarks |\n" \
        "|      |             |      | Chef   | Repository | Status      | Status      | Status     |         |\n" \
        "+------+-------------+------+--------+------------+-------------+-------------+------------+---------+\n" \
        "| #{'Test'.red} | ~> 1.0.0    |      | 1.1.0  | 1.1.0      |      #{X_MARK.red}      |      #{TICK_MARK.green}      |     #{TICK_MARK.green}      | 1       |\n" \
        "| #{'Test'.red} | ~> 1.0.0    |      | 1.1.0  | 1.1.0      |      #{X_MARK.red}      |      #{TICK_MARK.green}      |     #{TICK_MARK.green}      | 2       |\n" \
        "+------+-------------+------+--------+------------+-------------+-------------+------------+---------+\n" \
        "#{'Status: error (%s)'.red}\n\n" \
        "Remarks:\n" \
        "[1]: No versions found\n" \
        "[2]: No versions found" % X_MARK)
        expect(code).to eq(:error)
      end
    end
  end
end
