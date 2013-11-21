require_relative 'support/spec_helper'

describe Cli do
  before(:all) do
    # Disable stdout and stderr
    @original_stderr = $stderr
    @original_stdout = $stdout

    # Redirect stderr and stdout
    $stderr = File.open(File::NULL, 'w')
    $stdout = File.open(File::NULL, 'w')
  end

  after(:all) do
    $stderr = @original_stderr
    $stdout = @original_stdout
  end

  describe "investigate" do
    let(:cli) { Cli.new }

    it "raises a warning for cookbook without dependencies" do
      cli.options = { :config => File.new("#{File.dirname(__FILE__)}/data/test_config_valid.rb", 'r') }

      expect do
        cli.investigate("#{File.dirname(__FILE__)}/data/cookbook_no_deps")
      end.to exit_with_code(STATUS_TO_RETURN_CODES[:'warning-nodependencies'])
    end

    it "raises an error for missing configuration" do
      cli.options = { :config => 'notexisting.rb' }

      expect do
        cli.investigate
      end.to exit_with_code(STATUS_TO_RETURN_CODES[:'error-config'])
    end

    it "raises an error for missing cookbook" do
      cli.options = { :config => File.new("#{File.dirname(__FILE__)}/data/test_config_valid.rb", 'r') }

      expect do
        cli.investigate
      end.to exit_with_code(STATUS_TO_RETURN_CODES[:'error-notacookbook'])
    end
  end
end
