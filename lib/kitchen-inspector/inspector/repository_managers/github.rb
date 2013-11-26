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
require 'octokit'

module KitchenInspector
  module Inspector
    class GithubManager
      include BaseManager

      class GithubUsersNotConfiguredError < StandardError; end

      def initialize(config)
        super()
        raise GithubUsersNotConfiguredError, config_msg("Github users", "users") unless config[:users]

        @type = "Github"
        @users = config[:users]

        Octokit.configure do |c|
          c.access_token = config[:token]
          c.auto_paginate = true
        end
      end

      # Given a project and a revision retrieve its metadata
      def retrieve_metadata(project, revId)
        response = Octokit.contents(project.full_name,
                            {:ref => revId, :path => "metadata.rb" })

        if response && response.respond_to?(:content)
          metadata = Ridley::Chef::Cookbook::Metadata.new
          metadata.instance_eval(Base64.decode64(response.content))
          metadata
        else
          nil
        end
      end

      # Return the full URL for a given project
      def source_url(project)
        # "#{@Github_base_url}/#{project.path_with_namespace}"
      end

      # Retrieve a project by name
      def project_by_name(name)
        projects.select{|prj| prj.name == name }.first
      end

      # Iterate over @users' profiles to search for projects
      def projects
        @projects ||= begin
          @users.collect do |user|
            begin
              Octokit.repositories(user)
            rescue Octokit::NotFound
              # Skip repositories not found
            end
          end.flatten
        end
      end

      # Given a project return the tags on Github
      def retrieve_tags(project)
        tags = {}
        Octokit.tags(project.full_name).collect do |tag|
          tags[fix_version_name(tag.name)] = tag.commit.sha
        end
        tags
      end

      def to_s
        "#{@type} instance"
      end
    end
  end
end