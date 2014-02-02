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
    # Main class that, starting from a cookbook, analyzes its dependencies
    # using its "inspectors" and returns a collection of analyzed dependencies
    class HealthBureau
      include Utils

      attr_reader :chef_inspector, :repo_inspector

      def initialize(config)
        configuration = read_config(config)

        begin
          self.instance_eval configuration
        rescue NoMethodError => e
          raise ConfigurationError, "Unsupported configuration: #{e.name}."
        end

        raise ConfigurationError, "Chef Server is not configured properly, " \
                                  "please check your 'chef_server' configuration." unless validate_chef_inspector

        raise ConfigurationError, "Repository Manager is not configured properly, " \
                                  "please check your 'repository_manager' configuration." unless @repo_inspector
      end

      # Inspect your kitchen!
      #
      # If recursive is specified, dependencies' metadata are downloaded and recursively analyzed
      #
      # @param path [String] path to the cookbook to be analyzed
      # @param recursive [Boolean] whether transitive dependencies should be analyzed
      # @return [Array<Dependency>] analyzed dependency and its transitive dependencies
      def investigate(path, recursive=true)
        raise NotACookbookError, 'Path is not a cookbook' unless File.exists?(File.join(path, 'metadata.rb'))

        metadata = Ridley::Chef::Cookbook::Metadata.from_file(File.join(path, 'metadata.rb'))
        dependencies = metadata.dependencies.collect do |name, version|
          analyze_dependency(Models::Dependency.new(name, version), recursive)
        end.flatten

        @repo_inspector.manager.store_cache

        dependencies
      end

      # Analyze Chef repo and Repository manager in order to find more information
      # about a given dependency
      #
      # @param dependency [Dependency] dependency to be analyzed
      # @param recursive [Boolean] whether transitive dependencies should be analyzed
      # @return [Array<Dependency>] analyzed dependency and its transitive dependencies
      def analyze_dependency(dependency, recursive)
        chef_info = @chef_inspector.investigate(dependency)

        # Grab information from the Repository Manager
        info_repo = @repo_inspector.investigate(dependency, chef_info[:version_used], recursive)
        deps = info_repo.collect do |dep, repo_info|
          dep_chef_info = @chef_inspector.investigate(dep)
          update_dependency(dep, dep_chef_info, repo_info)
          dep
        end
        deps
      end

      # Update in-place a dependency based on information retrieved from
      # Chef Server and Repository Manager
      #
      # @param dependency [Dependency] dependency to be updated
      # @param chef_info [Hash] information from Chef Server
      # @param repo_info [Hash] information from Repository Manager
      def update_dependency(dependency, chef_info, repo_info)
        dependency.status = :up_to_date

        if !chef_info[:version_used]
          dependency.status = :err_req
          msg = 'No versions found'
          reference_version = @repo_inspector.get_reference_version(nil, repo_info)
          msg << ", using #{reference_version} for recursive analysis" if reference_version

          dependency.remarks << msg
        else
          relaxed_version = satisfy("~> #{chef_info[:version_used]}", chef_info[:versions])
          if relaxed_version != chef_info[:version_used]
            dependency.status = :warn_req
            changelog_url = @repo_inspector.get_changelog(repo_info,
                                          chef_info[:version_used],
                                          relaxed_version)
            dependency.remarks << "#{relaxed_version} is available. #{changelog_url}"
          end
        end

        # Compare Chef and Repository Manager versions
        comparison = compare_repo_chef(chef_info, repo_info)
        chef_info[:status] = comparison[:chef]
        repo_info[:status] = comparison[:repo]
        dependency.remarks.push(*comparison[:remarks]) if comparison[:remarks]

        if repo_info[:not_unique]
          repo_info[:status] = :warn_notunique_repo
          dependency.remarks << "Not unique on #{@repo_inspector.manager.type} (this is #{repo_info[:source_url]})"
        end

        # Check whether latest tag and metadata version in Repository Manager are
        # consistent
        unless @repo_inspector.consistent_version?(repo_info)
          repo_info[:status] = :warn_mismatch_repo
          dependency.remarks << "#{@repo_inspector.manager.type}'s last tag is #{repo_info[:latest_tag]} " \
                                  "but found #{repo_info[:latest_metadata]} in metadata.rb"
        end

        dependency.repomanager = repo_info
        dependency.chef = chef_info
      end

      # Compare Repository Manager and Chef Server
      #
      # @param chef_info [Hash] information from Chef Server
      # @param repo_info [Hash] information from Repository Manager
      # @return [Hash] containing servers statuses and remarks
      def compare_repo_chef(chef_info, repo_info)
        comparison = {:chef => :up_to_date, :repo => :up_to_date,
                  :remarks => []}

        if chef_info[:latest_version] && repo_info[:latest_metadata]
          if chef_info[:latest_version] > repo_info[:latest_metadata]
            comparison[:repo] = :warn_outofdate_repo
            changelog_url = @repo_inspector.get_changelog(repo_info,
                                          repo_info[:latest_metadata].to_s,
                                          chef_info[:latest_version].to_s)
            comparison[:remarks] << "#{@repo_inspector.manager.type} out-of-date! #{changelog_url}"
            return comparison
          elsif chef_info[:latest_version] < repo_info[:latest_metadata]
            comparison[:chef] = :warn_chef
            changelog_url = @repo_inspector.get_changelog(repo_info,
                                          chef_info[:latest_version].to_s,
                                          repo_info[:latest_metadata].to_s)
            comparison[:remarks] << "A new version might appear on Chef server. #{changelog_url}"
            return comparison
          end
        end

        unless repo_info[:latest_metadata]
          comparison[:repo] = :err_repo
          comparison[:remarks] << "#{@repo_inspector.manager.type} doesn't contain any versions."
        end

        unless chef_info[:latest_version]
          comparison[:chef] = :err_chef
          comparison[:remarks] << "Chef Server doesn't contain any versions."
        end

        comparison
      end

      # Initialize the Chef Server configuration
      def chef_server(config)
        @chef_inspector = ChefInspector.new config
      end

      # Initialize the Repository Manager
      def repository_manager(config)
        @repo_inspector = RepositoryInspector.new config
      end

      # Initialize a Chef Inspector using knife.rb settings if not already
      # initialized
      #
      # @return [ChefInspector]
      def validate_chef_inspector
        @chef_inspector ||= begin
          # Fallback to knife.rb if possible
          knife_cfg = "#{Dir.home}/.chef/knife.rb"
          if File.exists?(knife_cfg)
            Chef::Config.from_file knife_cfg
            chef_server({ :username => Chef::Config.node_name,
                          :url => Chef::Config.chef_server_url,
                          :client_pem => Chef::Config.client_key
                        })
          end
        end
      end
    end
  end
end