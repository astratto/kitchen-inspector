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
  require 'gitlab'
rescue LoadError
  raise KitchenInspector::Inspector::RepositoryManagerError,
    "GitLab support requires 'gitlab'. Please install it with 'gem install gitlab'."
end

module KitchenInspector
  module Inspector
    class GitLabAccessNotConfiguredError < StandardError; end

    class GitLabManager
      include BaseManager

      REPO_PER_PAGE = 1000

      def initialize(config)
        super()

        raise GitLabAccessNotConfiguredError, config_msg("GitLab base url", "base_url") unless config[:base_url]
        raise GitLabAccessNotConfiguredError, config_msg("GitLab Private Token", "token") unless config[:token]

        @type = "GitLab"
        @gitlab_token = config[:token]
        @gitlab_base_url = config[:base_url]
        @gitlab_api_url = "#{@gitlab_base_url}/api/v3"

        Gitlab.configure do |gitlab|
          gitlab.endpoint = @gitlab_api_url
          gitlab.private_token = @gitlab_token
          gitlab.user_agent = 'Kitchen Inspector'
        end
      end

      # Return the full URL for a given project
      def source_url(project)
        "#{@gitlab_base_url}/#{project.name}"
      end

      # Retrieve projects by name
      def projects_by_name(name)
        repos = projects.select{|prj| prj.path == name }
        repos.collect{|repo| Models::RepoCookbook.new(repo.id, repo.path_with_namespace, "metadata.rb")}
      end

      # Given a project and a revision retrieve its metadata
      def retrieve_metadata(project, revId)
        response = HTTParty.get("#{Gitlab.endpoint}/projects/#{project.id}/repository/blobs/#{revId}?filepath=#{project.metadata_path}",
                                headers: {"PRIVATE-TOKEN" => Gitlab.private_token})

        if response.code == 200
          eval_metadata response.body
        else
          nil
        end
      end

      # Given a project return the tags on GitLab
      def retrieve_tags(project)
        tags = {}
        Gitlab.tags(project.id).collect do |tag|
          tags[fix_version_name(tag.name)] = tag.commit.id
        end
        tags
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