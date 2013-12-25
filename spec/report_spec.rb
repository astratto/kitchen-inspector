require_relative 'support/spec_helper'

describe Report do
  let(:health_bureau) { generate_health_bureau }

  let(:chef_info) {
    chef = {:versions => ["1.0.0", "1.0.1"],
             :latest_version => Solve::Version.new("1.0.1"),
             :version_used => "1.0.1"}
  }

  let(:repomanager_info) {
    repomanager = {:tags => {"1.0.0" => "a", "1.0.1" => "b"},
                    :latest_metadata => Solve::Version.new("1.0.1"),
                    :latest_tag => Solve::Version.new("1.0.1")}
  }

  describe ".generate" do
    context "global status" do
      before(:each) do
        dep1 = Models::Dependency.new("Test", "~> 1.0.0")
        health_bureau.update_dependency(dep1, chef_info, repomanager_info)

        @dependencies = [dep1]
      end

      it "up_to_date" do
        output, code = Report.generate(@dependencies, 'table', {})
        expect(output.split("\n").grep(/Test|Status:/).join("\n")).to eq( \
        "| Test | ~> 1.0.0    | 1.0.1 | 1.0.1  | 1.0.1      |      #{TICK_MARK.green}      |      #{TICK_MARK.green}      |     #{TICK_MARK.green}      |\n" \
        "#{'Status: up_to_date (%s)'.green}" % TICK_MARK
        )
        expect(code).to eq(:up_to_date)
      end

      it "err_repo" do
        dep1 = @dependencies.first
        repomanager = {:tags => [],
                            :latest_metadata => nil,
                            :latest_tag => nil}

        health_bureau.update_dependency(dep1, dep1.chef, repomanager)

        output, code = Report.generate(@dependencies, 'table', {})
        expect(output.split("\n").grep(/Test|Status:/).join("\n")).to eq( \
        "| Test | ~> 1.0.0    | 1.0.1 | 1.0.1  |            |      #{TICK_MARK.green}      |      #{TICK_MARK.green}      |     #{X_MARK.yellow}      |\n" \
        "#{'Status: err_repo (%s)'.yellow}" % X_MARK
        )
        expect(code).to eq(:err_repo)
      end

      it "warn_mismatch_repo" do
        dep1 = @dependencies.first
        repomanager = {:tags => {"1.0.0" => "a"},
                            :latest_metadata => Solve::Version.new("1.0.0"),
                            :latest_tag => Solve::Version.new("1.0.1")}
        health_bureau.update_dependency(dep1, dep1.chef, repomanager)

        output, code = Report.generate(@dependencies, 'table', {})
        expect(output.split("\n").grep(/Test|Status:/).join("\n")).to eq( \
        "| Test | ~> 1.0.0    | 1.0.1 | 1.0.1  | 1.0.0      |      #{TICK_MARK.green}      |      #{TICK_MARK.green}      |     #{ESCLAMATION_MARK.bold.light_red}      |\n" \
        "#{'Status: warn_mismatch_repo (!)'.light_red}"
        )
        expect(code).to eq(:warn_mismatch_repo)
      end

      it "warn_outofdate_repo" do
        dep1 = @dependencies.first
        repomanager = {:tags => {"1.0.0" => "a"},
                            :latest_metadata => Solve::Version.new("1.0.0"),
                            :latest_tag => Solve::Version.new("1.0.0")}
        health_bureau.update_dependency(dep1, dep1.chef, repomanager)

        output, code = Report.generate(@dependencies, 'table', {})
        expect(output.split("\n").grep(/Test|Status:/).join("\n")).to eq( \
        "| Test | ~> 1.0.0    | 1.0.1 | 1.0.1  | 1.0.0      |      #{TICK_MARK.green}      |      #{TICK_MARK.green}      |     #{(ESCLAMATION_MARK * 2).bold.light_red}     |\n" \
        "#{'Status: warn_outofdate_repo (!!)'.light_red}"
        )
        expect(code).to eq(:warn_outofdate_repo)
      end

      it "warn_notunique_repo" do
        dep1 = @dependencies.first
        repomanager = {:tags => {"1.0.1" => "b"},
                            :latest_metadata => Solve::Version.new("1.0.1"),
                            :latest_tag => Solve::Version.new("1.0.1"),
                            :not_unique => true}
        health_bureau.update_dependency(dep1, dep1.chef, repomanager)

        output, code = Report.generate(@dependencies, 'table', {})
        expect(output.split("\n").grep(/Test|Status:/).join("\n")).to eq( \
        "| Test | ~> 1.0.0    | 1.0.1 | 1.0.1  | 1.0.1      |      #{TICK_MARK.green}      |      #{TICK_MARK.green}      |     #{QUESTION_MARK.light_red}      |\n" \
        "#{'Status: warn_notunique_repo (?)'.light_red}"
        )
        expect(code).to eq(:warn_notunique_repo)
      end

      it "warn_chef" do
        dep1 = @dependencies.first
        chef = {:versions => ["1.0.0"],
                     :latest_version => Solve::Version.new("1.0.0"),
                     :version_used => "1.0.0"}
        health_bureau.update_dependency(dep1, chef, dep1.repomanager)

        output, code = Report.generate(@dependencies, 'table', {})
        expect(output.split("\n").grep(/Test|Status:/).join("\n")).to eq( \
        "| Test | ~> 1.0.0    | 1.0.0 | 1.0.0  | 1.0.1      |      #{TICK_MARK.green}      |      #{INFO_MARK.bold.blue}      |     #{TICK_MARK.green}      |\n" \
        "#{'Status: warn_chef (i)'.blue}"
        )
        expect(code).to eq(:warn_chef)
      end

      it "warn_req" do
        dep1 = Models::Dependency.new("Test", "= 1.0.0")
        chef = {:versions => ["1.0.0", "1.0.1"],
                     :latest_version => Solve::Version.new("1.0.1"),
                     :version_used => "1.0.0"}
        repomanager = {:tags => {"1.0.0" => "a", "1.0.1" => "b"},
                            :latest_metadata => Solve::Version.new("1.0.1"),
                            :latest_tag => Solve::Version.new("1.0.1")}
        health_bureau.update_dependency(dep1, chef, repomanager)

        output, code = Report.generate([dep1], 'table', {})
        expect(output.split("\n").grep(/Test|Status:/).join("\n")).to eq( \
        "| Test | = 1.0.0     | 1.0.0 | 1.0.1  | 1.0.1      |      #{ESCLAMATION_MARK.bold.yellow}      |      #{TICK_MARK.green}      |     #{TICK_MARK.green}      |\n" \
        "#{'Status: warn_req (!)'.yellow}"
        )
        expect(code).to eq(:warn_req)
      end

      it "err due to wrong metadata" do
        dep1 = @dependencies.first
        chef = {:versions => ["1.1.0"],
                     :latest_version => Solve::Version.new("1.1.0"),
                     :version_used => nil}
        repomanager = {:tags => {"1.1.0" => "c"},
                            :latest_metadata => Solve::Version.new("1.1.0"),
                            :latest_tag => Solve::Version.new("1.1.0")}
        health_bureau.update_dependency(dep1, chef, repomanager)

        output, code = Report.generate([dep1], 'table', {})
        expect(output.split("\n").grep(/Test|Status:/).join("\n")).to eq( \
        "| #{'Test'.red} | ~> 1.0.0    |      | 1.1.0  | 1.1.0      |      #{X_MARK.red}      |      #{TICK_MARK.green}      |     #{TICK_MARK.green}      |\n" \
        "#{'Status: err_req (%s)'.red}" % X_MARK
        )
        expect(code).to eq(:err_req)
      end

      it "err due to Chef Server" do
        dep1 = @dependencies.first
        chef = {:versions => [],
                     :latest_version => nil,
                     :version_used => nil}
        health_bureau.update_dependency(dep1, chef, dep1.repomanager)

        output, code = Report.generate([dep1], 'table', {})
        expect(output.split("\n").grep(/Test|Status:/).join("\n")).to eq( \
        "| #{'Test'.red} | ~> 1.0.0    |      |        | 1.0.1      |      #{X_MARK.red}      |      #{X_MARK.red}      |     #{TICK_MARK.green}      |\n" \
        "#{'Status: err_req (%s)'.red}" % X_MARK
        )
        expect(code).to eq(:err_req)
      end

      it "shows remarks" do
        dep1 = @dependencies.first
        chef = {:versions => ["1.1.0"],
                     :latest_version => Solve::Version.new("1.1.0"),
                     :version_used => nil}
        repomanager = {:tags => {"1.1.0" => "c"},
                            :latest_metadata => Solve::Version.new("1.1.0"),
                            :latest_tag => Solve::Version.new("1.1.0")}
        health_bureau.update_dependency(dep1, chef, repomanager)

        output, code = Report.generate([dep1, dep1], 'table', {:remarks => true})
        expect(output).to eq( \
        "+------+-------------+------+--------+------------+-------------+-------------+------------+---------+\n" \
        "| Name | Requirement | Used | Chef   | Repository | Requirement | Chef Server | Repository | Remarks |\n" \
        "|      |             |      | Latest | Latest     | Status      | Status      | Status     |         |\n" \
        "+------+-------------+------+--------+------------+-------------+-------------+------------+---------+\n" \
        "| #{'Test'.red} | ~> 1.0.0    |      | 1.1.0  | 1.1.0      |      #{X_MARK.red}      |      #{TICK_MARK.green}      |     #{TICK_MARK.green}      | 1       |\n" \
        "| #{'Test'.red} | ~> 1.0.0    |      | 1.1.0  | 1.1.0      |      #{X_MARK.red}      |      #{TICK_MARK.green}      |     #{TICK_MARK.green}      | 2       |\n" \
        "+------+-------------+------+--------+------------+-------------+-------------+------------+---------+\n" \
        "#{'Status: err_req (%s)'.red}\n\n" \
        "Remarks:\n" \
        "[1]: No versions found, using 1.1.0 for recursive analysis\n" \
        "[2]: No versions found, using 1.1.0 for recursive analysis" % X_MARK)
        expect(code).to eq(:err_req)
      end

      it "shows remarks with changelog" do
        health_bureau.repo_inspector.stub(:get_changelog).and_return(
          "Changelog: test_url.short"
        )

        dep1 = @dependencies.first
        chef = {:versions => ["1.0.0"],
                     :latest_version => Solve::Version.new("1.0.0"),
                     :version_used => "1.0.0"}
        health_bureau.update_dependency(dep1, chef, dep1.repomanager)

        output, code = Report.generate(@dependencies, 'table', {:remarks => true})
        expect(output).to eq( \
        "+------+-------------+-------+--------+------------+-------------+-------------+------------+---------+\n" \
        "| Name | Requirement | Used  | Chef   | Repository | Requirement | Chef Server | Repository | Remarks |\n" \
        "|      |             |       | Latest | Latest     | Status      | Status      | Status     |         |\n" \
        "+------+-------------+-------+--------+------------+-------------+-------------+------------+---------+\n" \
        "| Test | ~> 1.0.0    | 1.0.0 | 1.0.0  | 1.0.1      |      #{TICK_MARK.green}      |      #{INFO_MARK.bold.blue}      |     #{TICK_MARK.green}      | 1       |\n" \
        "+------+-------------+-------+--------+------------+-------------+-------------+------------+---------+\n" \
        "#{'Status: warn_chef (i)'.blue}\n\n" \
        "Remarks:\n" \
        "[1]: A new version might appear on Chef server. Changelog: test_url.short")
        expect(code).to eq(:warn_chef)
      end

      it "shows nested dependencies" do
        dep1 = @dependencies.first
        dep2 = Models::Dependency.new("Nested", "~> 1.0.0")
        dep2.parents << dep1
        dep1.dependencies << dep2
        health_bureau.update_dependency(dep2, chef_info, repomanager_info)

        output, code = Report.generate([dep1, dep2], 'table', {:remarks => true})
        expect(output).to eq( \
        "+-----------+-------------+-------+--------+------------+-------------+-------------+------------+---------+\n" \
        "| Name      | Requirement | Used  | Chef   | Repository | Requirement | Chef Server | Repository | Remarks |\n" \
        "|           |             |       | Latest | Latest     | Status      | Status      | Status     |         |\n" \
        "+-----------+-------------+-------+--------+------------+-------------+-------------+------------+---------+\n" \
        "| Test      | ~> 1.0.0    | 1.0.1 | 1.0.1  | 1.0.1      |      #{TICK_MARK.green}      |      #{TICK_MARK.green}      |     #{TICK_MARK.green}      |         |\n" \
        "|  #{INDENT_MARK} Nested | ~> 1.0.0    | 1.0.1 | 1.0.1  | 1.0.1      |      #{TICK_MARK.green}      |      #{TICK_MARK.green}      |     #{TICK_MARK.green}      |         |\n" \
        "+-----------+-------------+-------+--------+------------+-------------+-------------+------------+---------+\n" \
        "#{'Status: up_to_date (%s)'.green}\n\n" \
        "Remarks:\n" % TICK_MARK)
        expect(code).to eq(:up_to_date)
      end
    end
  end
end
