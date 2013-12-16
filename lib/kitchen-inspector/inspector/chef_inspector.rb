#
# Copyright (c) 2013 Stefano Tortarolo <stefano.tortarolo@gmail.com>
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

module KitchenInspector
  module Inspector
    class ChefInspector
      include Utils

      def initialize(config)
        @chef_server_url = config[:url]
        @chef_username = config[:username]
        @chef_client_pem = config[:client_pem]

        raise ChefAccessNotConfiguredError, config_msg("Chef Server url", ":url") unless @chef_server_url
        raise ChefAccessNotConfiguredError, config_msg("Chef username", ":username") unless @chef_username
        raise ChefAccessNotConfiguredError, config_msg("Chef client PEM", ":client_pem") unless @chef_client_pem

        @chef_info_cache = {}
      end

      def investigate(dependency)
        cache_key = "#{dependency.name}, #{dependency.requirement}"
        @chef_info_cache[cache_key] ||= begin
          chef_info = {}
          chef_info[:versions] = find_versions(dependency.name)
          chef_info[:latest_version] = get_latest_version(chef_info[:versions])
          chef_info[:version_used] = satisfy(dependency.requirement, chef_info[:versions])
          chef_info
        end
      end

      # Given a project return the versions on the Chef Server
      def find_versions(project)
        rest = Chef::REST.new(@chef_server_url, @chef_username, @chef_client_pem)
        cookbook = rest.get("cookbooks/#{project}")
        versions = []
        versions = cookbook[project]["versions"].collect{|c| fix_version_name(c["version"])} if cookbook
        versions
      rescue Net::HTTPServerException
        []
      end
    end
  end
end