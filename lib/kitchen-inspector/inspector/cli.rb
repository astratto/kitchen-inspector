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
    class Cli < Thor
      default_task :investigate

      method_option :format, type: :string,
                             desc: 'The format to use for display',
                             enum: %w(table json),
                             default: 'table',
                             aliases: '-t'

      method_option :recursive, type: :boolean,
                             desc: 'Specify whether recursive dependencies must be analyzed',
                             default: true,
                             aliases: '-r'

      method_option :config, type: :string,
                             desc: 'The configuration to use',
                             default: File.join("#{Dir.home}", ".chef", "kitchen_inspector.rb"),
                             aliases: '-c'

      method_option :remarks, type: :boolean,
                             desc: 'Show remarks (useful to provide more descriptive information)',
                             default: false,
                             aliases: '--remarks'

      desc 'investigate (COOKBOOK_PATH)', 'Check Repository Manager/Chef Server status of dependent cookbooks'

      map 'inspect'   => :investigate
      def investigate(path=Dir.pwd)
        inspector = HealthBureau.new options[:config]

        dependencies = inspector.investigate(path, options[:recursive])

        if dependencies.empty?
          puts 'No dependent cookbooks'.yellow
          status_code = :'warning-nodependencies'
        else
          output, status_code = Report.generate(dependencies, options[:format], options)
          puts output
        end
        exit STATUS_TO_RETURN_CODES[status_code]
      rescue ConfigurationError => e
        puts e.message.red
        exit STATUS_TO_RETURN_CODES[:'error-config']
      rescue NotACookbookError
        puts 'The path is not a cookbook path'.red
        exit STATUS_TO_RETURN_CODES[:'error-notacookbook']
      rescue UnsupportedReportFormatError
        puts "The report format #{options[:format]} is not supported".red
        exit STATUS_TO_RETURN_CODES[:'error-reportformat']
      end
    end
  end
end
