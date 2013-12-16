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
    module Utils
      def config_msg(human_name, field)
        "#{human_name} not configured. Please set #{field} in your config file."
      end

      # Import a configuration from a file or StringIO
      def read_config(config)
        if config.is_a?(StringIO)
          config.string
        elsif File.exists?(config) && File.readable?(config)
          IO.read(config)
        else
          raise ConfigurationError, "Unable to load the configuration: '#{config}'.\nPlease refer to README.md and check that a valid configuration was provided."
        end
      end

      # Normalize version names to x.y.z...
      def fix_version_name(version)
        version.gsub(/[v][\.]*/i, "")
      end

      # Return from versions the best match that satisfies the given constraint
      def satisfy(constraint, versions)
        Solve::Solver.satisfy_best(constraint, versions).to_s
      rescue Solve::Errors::NoSolutionError
        nil
      end

      def get_latest_version(versions)
        versions.collect do |v|
          begin
            Solve::Version.new(v)
          rescue Solve::Errors::InvalidVersionFormat => e
            # Skip invalid tags
            Solve::Version.new("0.0.0")
          end
        end.max
      end
    end
  end
end
