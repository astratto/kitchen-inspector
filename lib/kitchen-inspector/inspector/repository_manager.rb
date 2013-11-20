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
    class GitlabManager
      include Commons

      REPO_PER_PAGE = 1000

      attr_reader :type

      def initialize(config)
        raise GitlabAccessNotConfiguredError, config_msg("Gitlab base url", "base_url") unless config[:base_url]
        raise GitlabAccessNotConfiguredError, config_msg("Gitlab Private Token", "token") unless config[:token]

        @type = "Gitlab"
        @gitlab_token = config[:token]
        @gitlab_base_url = config[:base_url]
        @gitlab_api_url = "#{@gitlab_base_url}/api/v3"

        Gitlab.configure do |gitlab|
          gitlab.endpoint = @gitlab_api_url
          gitlab.private_token = @gitlab_token
          gitlab.user_agent = 'Kitchen Inspector'
        end
      end

      # Given a project and a revision retrieve its dependencies from metadata.rb
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

      def source_url(project)
        "#{@gitlab_base_url}/#{project.path_with_namespace}"
      end

      def project_by_name(name)
        projects.select{|prj| prj.path == name }
      end

      # Given a project return the versions on Gitlab
      def versions(project)
        versions = {}
        Gitlab.tags(project.id).collect do |tag|
          versions[fix_version_name(tag.name)] = tag.commit.id
        end
        versions
      end

      def to_s
        "#{@type} instance: #{@gitlab_base_url}"
      end

      private
        def projects
          @projects ||= Gitlab.projects(:per_page => REPO_PER_PAGE)
        end
    end
  end
end