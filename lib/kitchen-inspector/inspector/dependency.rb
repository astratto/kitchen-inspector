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
    # The class that contains information about a dependent cookbook
    class Dependency
      # The name of the dependency
      attr_reader :name

      # The requirement for the dependency
      attr_reader :requirement

      # The version of cookbook used after applying the version constraint
      attr_accessor :version_used

      # The versions available on Chef Server
      attr_accessor :chef_versions

      # The latest version available on Chef Server
      attr_accessor :latest_chef

      # The versions available on Gitlab
      attr_accessor :gitlab_versions

      # The latest version available on Gitlab
      attr_accessor :latest_gitlab

      # The status of the dependency
      attr_accessor :status

      # The status of Gitlab
      attr_accessor :gitlab_status

      # The status of Chef Server
      attr_accessor :chef_status

      # The source URL for a cookbook
      attr_accessor :source_url

      # The dependencies of a cookbook
      attr_accessor :dependencies

      # Remarks field
      attr_accessor :remarks

      def initialize(name, requirement)
        @name = name
        @requirement = requirement
        @version_used = nil
        @chef_versions = []
        @latest_chef = nil
        @gitlab_versions = []
        @latest_gitlab = nil
        @status = nil
        @gitlab_status = nil
        @chef_status = nil
        @source_url = nil
        @remarks = []
        @dependencies = []
      end

      def to_hash
        {}.tap do |hash|
          hash[:name] = name
          hash[:requirement] = requirement
          hash[:used] = version_used
          hash[:chef_versions] = chef_versions
          hash[:latest_chef] = latest_chef
          hash[:gitlab_versions] = gitlab_versions
          hash[:latest_gitlab] = latest_gitlab
          hash[:status] = status
          hash[:gitlab_status] = gitlab_status
          hash[:chef_status] = chef_status
          hash[:source_url] = source_url
          hash[:remarks] = remarks
          hash[:dependencies] = dependencies
        end
      end
    end
  end
end
