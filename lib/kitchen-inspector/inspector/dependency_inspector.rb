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

        ridley = Ridley::Chef::Cookbook::Metadata.from_file(File.join(path, 'metadata.rb'))
        dependencies =
          ridley.dependencies.map do |name, version|
            Dependency.new(name, version)
          end
        populate_fields(dependencies, recursive)
      end

      # Initialize the Repository Manager
      def repository_manager(config)
        begin
          manager_cls = "KitchenInspector::Inspector::#{config[:type]}Manager".constantize
          @repomanager = manager_cls.new config
        rescue NameError
          raise RepositoryManagerError, "Repository Manager '#{config[:type]}' not supported."
        end
      end

      # Populate dependencies with information about their status
      def populate_fields(dependencies, recursive)
        dependencies.each do |dependency|
          dependency.chef_versions = find_chef_server_versions(dependency.name)
          dependency.version_used = satisfy(dependency.requirement, dependency.chef_versions)
          dependency.latest_chef = get_latest_version(dependency.chef_versions)

          # Grab information from the Repository Manager
          project = @repomanager.project_by_name(dependency.name)

          unless project.empty?
            raise DuplicateCookbookError, "Found two versions for #{dependency.name} on #{@repomanager.type}." if project.size > 1
            project = project.first

            repomanager_tags = @repomanager.tags(project)
            repomanager_latest_tag = get_latest_version(repomanager_tags.keys)

            dependency.repomanager_tags = repomanager_tags.keys
            dependency.latest_tag_repomanager = repomanager_latest_tag
            dependency.source_url = @repomanager.source_url(project)

            latest_version_repo = @repomanager.project_metadata_version(project, repomanager_tags[repomanager_latest_tag.to_s])
            dependency.latest_metadata_repomanager = Solve::Version.new(latest_version_repo) if latest_version_repo

            # Analyze its dependencies
            if recursive && repomanager_tags.include?(dependency.version_used)
              dependency.dependencies = @repomanager.project_dependencies(project, repomanager_tags[dependency.version_used])

              dependency.dependencies.each do |dep|
                unless dependencies.include?(dep)
                  dep.transitive = true
                  dependencies << dep
                end
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

      # Updates the status of the dependency based on the version used and the
      # latest version available on the Repository Manager
      def update_status(dependency)
        dependency.status = :'up-to-date'
        dependency.chef_status = :'up-to-date'
        dependency.repomanager_status = :'up-to-date'

        if !dependency.version_used
          dependency.status = :error
          dependency.remarks << 'No versions found'
        else
          relaxed_version = satisfy("~> #{dependency.version_used}", dependency.chef_versions)
          if relaxed_version != dependency.version_used
            dependency.status = :'warning-req'
            dependency.remarks << "#{relaxed_version} is available"
          end
        end

        # Compare Chef and Repository Manager versions
        if dependency.latest_chef && dependency.latest_metadata_repomanager
          if dependency.latest_chef > dependency.latest_metadata_repomanager
            dependency.chef_status = :'up-to-date'
            dependency.repomanager_status = :'warning-outofdate-repomanager'
            dependency.remarks << "#{@repomanager.type} out-of-date!"
          elsif dependency.latest_chef < dependency.latest_metadata_repomanager
            dependency.chef_status = :'warning-chef'
            dependency.repomanager_status = :'up-to-date'
            dependency.remarks << "A new version might appear on Chef server"
          end
        else
          unless dependency.latest_metadata_repomanager
            dependency.repomanager_status = :'error-repomanager'
            dependency.remarks << "#{@repomanager.type} doesn't contain any versions."
          end

          unless dependency.latest_chef
            dependency.chef_status = :'error-chef'
            dependency.remarks << "Chef Server doesn't contain any versions."
          end
        end

        # Check whether last tag and metadata version in Repository Manager are
        # consistent
        if (dependency.latest_tag_repomanager &&
            dependency.latest_metadata_repomanager &&
            dependency.latest_tag_repomanager != dependency.latest_metadata_repomanager)
          dependency.repomanager_status = :'warning-mismatch-repomanager'
          dependency.remarks << "#{@repomanager.type}'s last tag is #{dependency.latest_tag_repomanager} " \
                                  "but found #{dependency.latest_metadata_repomanager} in metadata.rb"
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