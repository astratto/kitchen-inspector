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
      include Utils

      def initialize(config)
        configure(config)
      end

      def configure(config)
        configuration = read_config(config)

        begin
          self.instance_eval configuration
        rescue NoMethodError => e
          raise ConfigurationError, "Unsupported configuration: #{e.name}"
        end

        raise ChefAccessNotConfiguredError, config_msg("Chef server url", "chef_server_url") unless @chef_server_url
        raise ChefAccessNotConfiguredError, config_msg("Chef username", "chef_username") unless @chef_username
        raise ChefAccessNotConfiguredError, config_msg("Chef client PEM", "chef_client_pem") unless @chef_client_pem
      end

      # Inspect your kitchen!
      #
      # If recursive is specified, dependencies' metadata are downloaded and recursively analyzed
      def investigate(path, recursive=true)
        raise NotACookbookError, 'Path is not a cookbook' unless File.exists?(File.join(path, 'metadata.rb'))

        metadata = Ridley::Chef::Cookbook::Metadata.from_file(File.join(path, 'metadata.rb'))
        metadata.dependencies.collect do |name, version|
          analyze_dependency(Dependency.new(name, version), recursive)
        end.flatten
      end

      # Initialize the Repository Manager
      def repository_manager(config)
        begin
          manager_cls = "KitchenInspector::Inspector::#{config[:type]}Manager".constantize
        rescue NameError => e
          raise RepositoryManagerError, "Repository Manager '#{config[:type]}' not supported"
        end

        @repomanager = manager_cls.new config
      end

      # Analyze Chef repo and Repository manager in order to find more information
      # about a given dependency
      def analyze_dependency(dependency, recursive)
        repo_info = {}

        chef_info = {}
        chef_info[:versions] = find_chef_server_versions(dependency.name)
        chef_info[:latest_version] = get_latest_version(chef_info[:versions])
        chef_info[:version_used] = satisfy(dependency.requirement, chef_info[:versions])

        # Grab information from the Repository Manager
        projects = @repomanager.projects_by_name(dependency.name)

        unless projects.empty?
          raise DuplicateCookbookError, "Found two versions for #{dependency.name} on #{@repomanager.type}." if projects.size > 1
          project = projects.first
          repo_info = analyze_from_repository(project)
        end
        update_dependency(dependency, chef_info, repo_info)

        # Analyze its dependencies based on Repository Manager
        if recursive && repo_info[:tags] && repo_info[:tags].include?(chef_info[:version_used])
          dependency.dependencies = @repomanager.project_dependencies(project, repo_info[:tags][chef_info[:version_used]])

          [dependency, dependency.dependencies.collect do |dep|
              dep.parents << dependency
              analyze_dependency(dependency, recursive)
            end]
        else
          [dependency]
        end
      end

      # Return from versions the best match that satisfies the given constraint
      def satisfy(constraint, versions)
        Solve::Solver.satisfy_best(constraint, versions).to_s
      rescue Solve::Errors::NoSolutionError
        nil
      end

      # Retrieve project info from Repository Manager
      def analyze_from_repository(project)
        tags = @repomanager.tags(project)
        latest_tag = get_latest_version(tags.keys)

        latest_metadata = @repomanager.project_metadata_version(project, tags[latest_tag.to_s])
        latest_metadata = Solve::Version.new(latest_metadata) if latest_metadata

        {:tags => tags,
         :latest_tag => latest_tag,
         :latest_metadata => latest_metadata,
         :source_url => @repomanager.source_url(project)
        }
      end

      # Update the status of the dependency based on the version used and the
      # latest version available on the Repository Manager
      def update_dependency(dependency, chef_info, repo_info)
        dependency.status = :'up-to-date'

        if !chef_info[:version_used]
          dependency.status = :error
          dependency.remarks << 'No versions found'
        else
          relaxed_version = satisfy("~> #{chef_info[:version_used]}", chef_info[:versions])
          if relaxed_version != chef_info[:version_used]
            dependency.status = :'warning-req'
            dependency.remarks << "#{relaxed_version} is available"
          end
        end

        # Compare Chef and Repository Manager versions
        comparison = compare_repo_chef(chef_info, repo_info)
        chef_info[:status] = comparison[:chef]
        repo_info[:status] = comparison[:repo]
        dependency.remarks.push(*comparison[:remarks]) if comparison[:remarks]

        # Check whether latest tag and metadata version in Repository Manager are
        # consistent
        unless repomanager_consistent?(repo_info)
          repo_info[:status] = :'warning-mismatch-repomanager'
          dependency.remarks << "#{@repomanager.type}'s last tag is #{repo_info[:latest_tag]} " \
                                  "but found #{repo_info[:latest_metadata]} in metadata.rb"
        end

        dependency.repomanager = repo_info
        dependency.chef = chef_info
      end

      # Compare Repository Manager and Chef Server
      def compare_repo_chef(chef_info, repo_info)
        comparison = {:chef => :'up-to-date', :repo => :'up-to-date',
                  :remarks => []}

        if chef_info[:latest_version] && repo_info[:latest_metadata]
          if chef_info[:latest_version] > repo_info[:latest_metadata]
            comparison[:repo] = :'warning-outofdate-repomanager'
            comparison[:remarks] << "#{@repomanager.type} out-of-date!"
            return comparison
          elsif chef_info[:latest_version] < repo_info[:latest_metadata]
            comparison[:chef] = :'warning-chef'
            comparison[:remarks] << "A new version might appear on Chef server"
            return comparison
          end
        end

        unless repo_info[:latest_metadata]
          comparison[:repo] = :'error-repomanager'
          comparison[:remarks] << "#{@repomanager.type} doesn't contain any versions."
        end

        unless chef_info[:latest_version]
          comparison[:chef] = :'error-chef'
          comparison[:remarks] << "Chef Server doesn't contain any versions."
        end

        comparison
      end

      def repomanager_consistent?(info)
        !(info[:latest_tag] &&
          info[:latest_metadata] &&
            info[:latest_tag] != info[:latest_metadata])
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

      def inspect
        "Repository Manager: #{@repomanager.type}\n" \
        "\t#{@repomanager}\n" \
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

        def chef_server_url(url)
          @chef_server_url = url
        end

        def chef_username(username)
          @chef_username = username
        end

        def chef_client_pem(filename)
          @chef_client_pem = filename
        end
    end
  end
end