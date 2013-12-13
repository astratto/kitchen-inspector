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
    module BaseManager
      include Utils

      attr_reader :type

      def initialize
        # Cache metadata and tags to reduce calls against the Repository Manager
        @metadata_cache = {}
        @tags_cache = {}
        @changelogs_cache = {}
        @type = "BaseManager"
      end

      # Return the full URL for a given project
      def source_url(project)
        raise NotImplementedError
      end

      # Retrieve projects by name
      def projects_by_name(name)
        raise NotImplementedError
      end

      # Retrieve project's metadata
      def retrieve_metadata(project)
        raise NotImplementedError
      end

      # Given a project return its tags
      def retrieve_tags(project)
        raise NotImplementedError
      end

      # Given a project and a revision retrieve its dependencies from metadata.rb
      def project_dependencies(project, revId)
        return nil unless project && revId

        metadata = project_metadata(project, revId)

        if metadata
          metadata.dependencies.collect{|dep, constraint| Dependency.new(dep, constraint)}
        end
      end

      # Given a project and a revision retrieve its metadata's version
      def project_metadata_version(project, revId)
        return nil unless project && revId

        metadata = project_metadata(project, revId)

        if metadata
          fix_version_name(metadata.version)
        end
      end

      # Given a project and a revision retrieve its metadata
      def project_metadata(project, revId)
        cache_key = "#{project.id}-#{revId}"
        @metadata_cache[cache_key] ||=
          begin
            retrieve_metadata(project, revId)
          end
      end

      # Given a project return the tags on Gitlab
      def tags(project)
        cache_key = project.id
        @tags_cache[cache_key] ||= retrieve_tags(project)
      end

      # Return a shortened url to the commits between two revisions
      def changelog(project_url, revId, otherRevId)
        return unless project_url && revId && otherRevId
        cache_key = "#{project_url}-#{revId}-otherRevId"

        @changelogs_cache[cache_key] ||=
          begin
            Googl.shorten("#{project_url}/compare/#{revId}...#{otherRevId}").short_url.gsub(/^http:\/\//, '')
          end
      end
    end
  end
end