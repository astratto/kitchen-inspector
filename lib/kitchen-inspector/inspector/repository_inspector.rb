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
    class RepositoryInspector
      include Utils

      attr_accessor :manager

      def initialize(config)
        begin
          require "kitchen-inspector/inspector/repository_managers/#{config[:type].downcase}"
          manager_cls = "KitchenInspector::Inspector::#{config[:type]}Manager".constantize
        rescue LoadError, NameError => e
          raise RepositoryManagerError, "Repository Manager '#{config[:type]}' not supported."
        end

        @manager = manager_cls.new config
      end

      # Given a dependency and a version provided by Chef Server,
      # analyze that dependency and its transitive dependencies (if recursive)
      #
      # It also detects whether multiple projects exist with the same name
      # e.g., different users or forks
      #
      # @return [Array] containing pairs [dependency, repository_information]
      def investigate(dependency, version_used, recursive)
        repo_dependencies = []
        projects = @manager.projects_by_name(dependency.name)

        if projects.empty?
          repo_dependencies << [dependency, {}]
        else
          projects.each do |project|
            repo_info = analyze_repository(project)
            repo_info[:not_unique] = projects.size > 1

            # Inherit only shallow information from dependency
            prj_dependency = Models::Dependency.new(dependency.name, dependency.requirement)
            prj_dependency.parents = dependency.parents

            prj_dependency.parents.each do |parent|
              parent.dependencies << prj_dependency
            end

            repo_dependencies << [prj_dependency, repo_info]

            # Analyze its dependencies based on Repository Manager
            if recursive && repo_info[:tags]
              reference_version = get_reference_version(version_used, repo_info)

              children = @manager.project_dependencies(project,
                                    repo_info[:tags][reference_version]).collect do |dep|
                dep.parents << prj_dependency
                investigate(dep, version_used, recursive)
              end.flatten!(1)

              repo_dependencies.push(*children)
            end
          end
        end

        repo_dependencies
      end

      # Return the reference version to be used for recursive analysis
      #
      # It's the version used, if present. The latest available tag on the Repository
      # Manager otherwise.
      def get_reference_version(version_used, repo_info)
        reference_version = nil
        reference_version = version_used if version_used && repo_info[:tags].include?(version_used)
        reference_version = repo_info[:latest_tag].to_s unless reference_version
        reference_version
      end

      # Check whether tag and metadata's version match
      def consistent_version?(info)
        !(info[:latest_tag] &&
          info[:latest_metadata] &&
            info[:latest_tag] != info[:latest_metadata])
      end

      # Return an url pointing to the diff between startRev and endRev
      def get_changelog(repo_info, startRev, endRev)
        return unless repo_info[:tags]

        url = @manager.changelog(repo_info[:source_url],
                                               repo_info[:tags][startRev],
                                               repo_info[:tags][endRev])
        "Changelog: #{url}" if url
      end

      # Retrieve project info from Repository Manager
      def analyze_repository(project)
        tags = @manager.tags(project)
        latest_tag = get_latest_version(tags.keys)

        latest_metadata = @manager.project_metadata_version(project, tags[latest_tag.to_s])
        latest_metadata = Solve::Version.new(latest_metadata) if latest_metadata

        {:tags => tags,
         :latest_tag => latest_tag,
         :latest_metadata => latest_metadata,
         :source_url => @manager.source_url(project)
        }
      end
    end
  end
end