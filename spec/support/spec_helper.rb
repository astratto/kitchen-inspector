require 'coveralls'
Coveralls.wear!

require 'kitchen-inspector/inspector'
require 'chef_zero/server'

include KitchenInspector::Inspector

RSpec.configure do |config|
  config.before(:all) do
    @chef_server = ChefZero::Server.new(port: 4000)
    @chef_server.start_background
  end

  config.after(:all) do
    @chef_server.stop
  end
end

def generate_dependency_inspector
  config = StringIO.new
  config.puts "repository_manager :type => 'Gitlab', :base_url => 'http://localhost:8080', :token =>'test_token'"
  config.puts "chef_server_url 'http://localhost:4000'"
  config.puts "chef_client_pem 'testclient.pem'"
  config.puts "chef_username 'test_user'"

  inspector = DependencyInspector.new config
  inspector
end