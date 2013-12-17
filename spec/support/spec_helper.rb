require 'coveralls'
Coveralls.wear!

require 'kitchen-inspector/inspector'
require 'kitchen-inspector/inspector/repository_managers/github'
require 'kitchen-inspector/inspector/repository_managers/gitlab'

require 'chef_zero/server'

include KitchenInspector::Inspector

RSpec.configure do |config|
  config.before(:all) do
    @chef_server = ChefZero::Server.new(port: 4000)
    @chef_server.start_background
  end

  config.after(:each) do
    @chef_server.clear_data
  end

  config.after(:all) do
    @chef_server.stop
  end

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

def generate_health_bureau
  config = StringIO.new
  config.puts "repository_manager :type => 'Gitlab', :base_url => 'http://localhost:8080', :token =>'test_token'"
  config.puts "chef_server :url => 'http://localhost:4000', :client_pem => '%s', :username => 'test_user'" % "#{File.dirname(__FILE__)}/../data/test_client.pem"

  inspector = HealthBureau.new config
  inspector
end

RSpec::Matchers.define :exit_with_code do |exp_code|
  actual = nil
  match do |block|
    begin
      block.call
    rescue SystemExit => e
      actual = e.status
    end
    actual and actual == exp_code
  end
  failure_message_for_should do |block|
    "expected block to call exit(#{exp_code}) but exit" +
      (actual.nil? ? " not called" : "(#{actual}) was called")
  end
  failure_message_for_should_not do |block|
    "expected block not to call exit(#{exp_code})"
  end
  description do
    "expect block to call exit(#{exp_code})"
  end
end

## Define File::NULL for ruby < 1.9.3
#
# Shamelessly stolen from backports
# https://github.com/marcandre/backports/blob/master/lib/backports/1.9.3/file/null.rb
unless File.const_defined? :NULL
  module File::Constants
    platform = RUBY_PLATFORM
    platform = RbConfig::CONFIG['host_os'] if platform == 'java'
    NULL =  case platform
            when /mswin|mingw/i
              'NUL'
            when /amiga/i
              'NIL:'
            when /openvms/i
              'NL:'
            else
              '/dev/null'
            end
  end
end