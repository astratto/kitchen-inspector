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
begin
  require 'octokit'
rescue LoadError
  raise KitchenInspector::Inspector::RepositoryManagerError,
    "GitHub support requires 'octokit'. Please install it with 'gem install octokit'."
end

module KitchenInspector
  module Inspector
    class GitHubManager
      include BaseManager

      class GitHubUsersNotConfiguredError < StandardError; end

      def initialize(config)
        super()
        raise GitHubUsersNotConfiguredError, config_msg("GitHub allowed users", "allowed_users") unless config[:allowed_users]

        @type = "GitHub"
        @allowed_users = config[:allowed_users]
        @projects_cache = {}

        Octokit.configure do |c|
          c.access_token = config[:token]
          c.auto_paginate = true
        end

        load_cache
      end

      # Given a project and a revision retrieve its metadata
      def retrieve_metadata(project, revId)
        response = Octokit.contents(project.name,
                            {:ref => revId, :path => project.metadata_path })

        if response && response.respond_to?(:content)
          eval_metadata Base64.decode64(response.content)
        else
          nil
        end
      end

      # Return the full URL for a given project
      def source_url(project)
        "github.com/#{project.name}"
      end

      # Retrieve projects by name
      #
      # Scan allowed_users' repositories in order to detect cookbooks matching 'name'
      # in their metadata.rb
      #
      # @param name [String] name of the cookbook to search for
      # @return [Array<RepoCookbook>] cookbooks matching search criteria
      def projects_by_name(name)
        @projects_cache[name] ||= begin
          projects = []

          @allowed_users.each do |user|
            repos = Octokit.repos user
            repos.each do |repo|
              project = Models::RepoCookbook.new(repo.id, repo.full_name,
                                      "metadata.rb", repo.updated_at)

              # Match against metadata.rb's name
              content = Octokit.contents repo.full_name
              if is_a_cookbook?(content)
                # Metadata.rb in repo's root
                metadata = project_metadata(project, "master")
                projects << project if metadata
              end
            end
          end

          projects
        end
      end

      # Given a project return the tags on GitHub
      def retrieve_tags(project)
        tags = {}
        Octokit.tags(project.name).collect do |tag|
          tags[fix_version_name(tag.name)] = tag.commit.sha
        end
        tags
      end

      def to_s
        "#{@type} instance"
      end

      private
        def is_a_cookbook?(content)
          content.any?{|f| f.type == "file" && f.name == "metadata.rb"}
        end

        def store_cache
          require 'byebug'
          byebug

          File.open("#{Dir.home}/.chef/.kitchen-inspector.cache", "w") do |cache|
            cache.write @projects_cache.to_json
          end
        end

        def load_cache
          cache_file = "#{Dir.home}/.chef/.kitchen-inspector.cache"

          require 'byebug'
          byebug
          if File.exists? cache_file
            @projects_cache = JSON.parse File.read(cache_file)
          else
            init_cache
          end
          @projects_cache
        end

        def init_cache
          @allowed_users.each do |user|
            repos = Octokit.repos user
            repos.each do |repo|
              puts "Init cache for #{repo.full_name}"
              project = Models::RepoCookbook.new(repo.id, repo.full_name, "metadata.rb", repo.updated_at)

              # Match against metadata.rb's name
              content = Octokit.contents repo.full_name
              if is_a_cookbook?(content)
                # Metadata.rb in repo's root
                project_metadata(project, "master")
              end
            end
          end
          store_cache
        end
    end
  end
end