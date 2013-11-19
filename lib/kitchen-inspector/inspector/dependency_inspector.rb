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
    class DependencyInspector
      REPO_PER_PAGE = 1000

      def initialize(config)
        read_config(config)

        @gitlab_api_url = "#{@gitlab_base_url}/api/v3"

        Gitlab.configure do |gitlab|
          gitlab.endpoint = @gitlab_api_url
          gitlab.private_token = @gitlab_token
          gitlab.user_agent = 'Kitchen Inspector'
        end
      end

      # Import a configuration from a file or StringIO
      def read_config(config)
        if config.is_a?(StringIO)
          configuration = config.string
        elsif File.exists?(config) && File.readable?(config)
          configuration = IO.read(config)
        else
          raise ConfigurationError, "Unable to load the configuration: '#{config}'.\nPlease refer to README.md and check that a valid configuration was provided."
        end

        self.instance_eval configuration

        raise GitlabAccessNotConfiguredError, config_msg("Gitlab base url", "gitlab_base_url") unless @gitlab_base_url
        raise GitlabAccessNotConfiguredError, config_msg("Gitlab Private Token", "gitlab_token") unless @gitlab_token

        raise ChefAccessNotConfiguredError, config_msg("Chef server url", "chef_server_url") unless @chef_server_url
        raise ChefAccessNotConfiguredError, config_msg("Chef username", "chef_username") unless @chef_username
        raise ChefAccessNotConfiguredError, config_msg("Chef client PEM", "chef_client_pem") unless @chef_client_pem
      end

      def investigate(path, recursive=true)
        raise NotACookbookError, 'Path is not a cookbook' unless File.exists?(File.join(path, 'metadata.rb'))

        ridley = Ridley::Chef::Cookbook::Metadata.from_file(File.join(path, 'metadata.rb'))
        dependencies =
          ridley.dependencies.map do |name, version|
            Dependency.new(name, version)
          end
        populate_fields(dependencies, recursive)
      end

      def populate_fields(dependencies, recursive)
        projects = Gitlab.projects(:per_page => REPO_PER_PAGE)

        dependencies.each do |dependency|
          dependency.chef_versions = find_chef_server_versions(dependency.name)
          dependency.version_used = satisfy(dependency.requirement, dependency.chef_versions)

          # Grab information from Gitlab
          project = projects.select do |pr|
            pr.path == "#{dependency.name}"
          end

          unless project.empty?
            raise DuplicateCookbookError, "Found two versions for #{dependency.name} on Gitlab." if project.size > 1
            project = project.first

            gitlab_versions = find_gitlab_versions(project)
            dependency.gitlab_versions = gitlab_versions.keys
            dependency.source_url = "#{@gitlab_base_url}/#{project.path_with_namespace}"

            # Analyze its dependencies
            if recursive && gitlab_versions.include?(dependency.version_used)
              dependency.dependencies = retrieve_dependencies(project, gitlab_versions[dependency.version_used])

              # Add dependencies not already tracked
              dependency.dependencies.each do |dep|
                dependencies << dep unless dependencies.collect(&:name).include?(dep.name)
              end
            end
          end

          update_status(dependency)
        end
      end

      # Return from versions the best match that satisfies the given constraint
      def satisfy(constraint, versions)
        Solve::Solver.satisfy_best(constraint, versions).to_s
      rescue Solve::Errors::NoSolutionError
        nil
      end

      # Given a project and a revision retrieve its dependencies
      def retrieve_dependencies(project, revId)
        return nil unless project && revId

        response = HTTParty.get("#{Gitlab.endpoint}/projects/#{project.id}/repository/blobs/#{revId}?filepath=metadata.rb",
                                headers: {"PRIVATE-TOKEN" => Gitlab.private_token})

        if response.code == 200
          metadata = Ridley::Chef::Cookbook::Metadata.new
          metadata.instance_eval response.body
          metadata.dependencies.collect{|dep, constraint| Dependency.new(dep, constraint)}
        else
          nil
        end
      end

      # Updates the status of the dependency based on the version used and the latest version available on Gitlab
      def update_status(dependency)
        dependency.latest_chef = get_latest_version(dependency.chef_versions)
        dependency.latest_gitlab = get_latest_version(dependency.gitlab_versions)

        dependency.status = 'up-to-date'
        dependency.chef_status = 'up-to-date'
        dependency.gitlab_status = 'up-to-date'

        if !dependency.version_used
          dependency.status = 'error'
          dependency.remarks << 'No versions found'
        else
          relaxed_version = satisfy("~> #{dependency.version_used}", dependency.chef_versions)
          if relaxed_version != dependency.version_used
            dependency.status = 'warning-req'
            dependency.remarks << "#{relaxed_version} is available"
          end
        end

        if dependency.latest_chef && dependency.latest_gitlab
          if dependency.latest_chef > dependency.latest_gitlab
            dependency.chef_status = 'up-to-date'
            dependency.gitlab_status = 'warning-gitlab'
            dependency.remarks << "Gitlab out-of-date!"
          elsif dependency.latest_chef < dependency.latest_gitlab
            dependency.chef_status = 'warning-chef'
            dependency.gitlab_status = 'up-to-date'
            dependency.remarks << "A new version might appear on Chef server"
          end
        else
          unless dependency.latest_gitlab
            dependency.gitlab_status = 'error-gitlab'
            dependency.remarks << "Gitlab doesn't contain any versions."
          end

          unless dependency.latest_chef
            dependency.chef_status = 'error-chef'
            dependency.remarks << "Chef Server doesn't contain any versions."
          end
        end
      end

      # Given a project return the versions on the Chef Server
      def find_chef_server_versions(project)
        rest = Chef::REST.new(@chef_server_url, @chef_username, @chef_client_pem)
        cookbook = rest.get("cookbooks/#{project}")
        versions = []
        versions = cookbook[project]["versions"].collect{|c| fix_version_name(c["version"])} if cookbook
        versions
      rescue Net::HTTPServerException
        []
      end

      # Given a project return the versions on Gitlab
      def find_gitlab_versions(project)
        versions = {}
        Gitlab.tags(project.id).collect do |tag|
          versions[fix_version_name(tag.name)] = tag.commit.id
        end
        versions
      end

      def inspect
        "Gitlab base url: #{@gitlab_base_url}\n" \
        "Gitlab token: #{@gitlab_token}\n" \
        "Chef server url: #{@chef_server_url}\n" \
        "Chef username: #{@chef_username}\n" \
        "Chef client pem: #{@chef_client_pem}"
      end

      private
        def fix_version_name(version)
          version.gsub(/[v][\.]*/i, "")
        end

        def get_latest_version(versions)
          versions.collect{|v| Solve::Version.new(v)}.max
        end

        def gitlab_base_url(url)
          @gitlab_base_url = url
        end

        def gitlab_token(token)
          @gitlab_token = token
        end

        def chef_server_url(url)
          @chef_server_url = url
        end

        def chef_username(username)
          @chef_username = username
        end

        def chef_client_pem(filename)
          @chef_client_pem = filename
        end

        def config_msg(human_name, field)
          "#{human_name} not configured. Please set #{field} in your config file."
        end
    end
  end
end