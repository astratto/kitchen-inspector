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
      GITLAB_BASE_URL = ENV['GITLAB_URL']
      GITLAB_API_URL = "#{GITLAB_BASE_URL}/api/v3"
      CHEF_SERVER_URL = ENV['CHEF_SERVER_URL']
      CHEF_USERNAME = ENV['CHEF_USERNAME']
      CHEF_CLIENT_PEM = ENV['CHEF_CLIENT_PEM']
      GITLAB_TOKEN = ENV['GITLAB_TOKEN']

      raise GitlabAccessNotConfiguredError, "Gitlab URL not configured. Please set it in ENV['GITLAB_URL']" unless GITLAB_BASE_URL
      raise GitlabAccessNotConfiguredError, "Private Token not configured. Please set it in ENV['GITLAB_TOKEN']" unless GITLAB_TOKEN

      raise ChefAccessNotConfiguredError, "Please set ENV['CHEF_SERVER_URL']" unless CHEF_SERVER_URL
      raise ChefAccessNotConfiguredError, "Please set ENV['CHEF_USERNAME']" unless CHEF_USERNAME
      raise ChefAccessNotConfiguredError, "Please set ENV['CHEF_CLIENT_PEM']" unless CHEF_CLIENT_PEM

      Gitlab.configure do |config|
        config.endpoint = GITLAB_API_URL
        config.private_token = GITLAB_TOKEN
        config.user_agent = 'Kitchen Inspector'
      end

      def self.investigate(path, recursive=true)
        raise NotACookbookError, 'Path is not a cookbook' unless File.exists?(File.join(path, 'metadata.rb'))

        ridley = Ridley::Chef::Cookbook::Metadata.from_file(File.join(path, 'metadata.rb'))
        dependencies =
          ridley.dependencies.map do |name, version|
            Dependency.new(name, version)
          end
        populate_fields(dependencies, recursive)
      end

      def self.populate_fields(dependencies, recursive)
        projects = Gitlab.projects(:per_page => REPO_PER_PAGE)

        dependencies.each do |dependency|
          # Skip cookbooks that are not available on Gitlab.
          project = projects.select do |pr|
            pr.path == "#{dependency.name}"
          end

          unless project.empty?
            raise DuplicateCookbookError, "Found two versions for #{dependency.name} on Gitlab." if project.size > 1
            project = project.first

            gitlab_versions = find_gitlab_versions(project)
            dependency.gitlab_versions = gitlab_versions.keys
            dependency.chef_versions = find_chef_server_versions(project.path)
            dependency.version_used = satisfy(dependency.requirement, dependency.chef_versions)
            dependency.source_url = "#{GITLAB_BASE_URL}/#{project.path_with_namespace}"

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

      def self.satisfy(constraint, versions)
        Solve::Solver.satisfy_best(constraint, versions).to_s
      rescue Solve::Errors::NoSolutionError
        nil
      end

      def self.retrieve_dependencies(project, tagId)
        return nil unless project && tagId

        response = HTTParty.get("#{Gitlab.endpoint}/projects/#{project.id}/repository/blobs/#{tagId}?filepath=metadata.rb",
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
      def self.update_status(dependency)
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
          dependency.gitlab_status = 'error-gitlab' unless dependency.latest_gitlab
          dependency.chef_status = 'error-chef' unless dependency.latest_chef
        end
      end

      def self.find_chef_server_versions(project)
        rest = Chef::REST.new(CHEF_SERVER_URL, CHEF_USERNAME, CHEF_CLIENT_PEM)
        cookbook = rest.get("cookbooks/#{project}")
        versions = []
        versions = cookbook[project]["versions"].collect{|c| fix_version_name(c["version"])} if cookbook
        versions
      rescue Net::HTTPServerException
        []
      end

      def self.find_gitlab_versions(project)
        versions = {}
        Gitlab.tags(project.id).collect do |tag|
          versions[fix_version_name(tag.name)] = tag.commit.id
        end
        versions
      end

      def self.fix_version_name(version)
        version.gsub(/[v][\.]*/i, "")
      end

      def self.get_latest_version(versions)
        versions.collect{|v| Solve::Version.new(v)}.max
      end
    end
  end
end