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
    # The ASCII code for tick mark symbol
    TICK_MARK = "\u2714"
    # The ASCII code for X mark symbol
    X_MARK = "\u2716"
    ESCLAMATION_MARK = "!"
    INFO_MARK = "i"

    class Report
      class << self
        # Generates the status of dependent cookbooks in specified format
        #
        # @param dependencies [Array<Dependency>] list of cookbook dependency objects
        # @param format [String] the format used for Report
        #
        def generate(dependencies, format, opts={})
          case format
          when 'table'
            TableReport.generate(dependencies, opts)
          when'json'
            JSONReport.generate(dependencies)
          else
            raise UnsupportedReportFormatError, "Report format '#{format}' is not supported"
          end
        end
      end
    end

    # Reports the cookbook dependency status in a table format
    #
    class TableReport
      class << self
        # Generate the status of dependent cookbooks as a table
        def generate(dependencies, opts)
          headings = ["Name", "Requirement", "Used", "Latest\nChef", "Latest\nRepository", "Requirement\nStatus",
                      "Chef Server\nStatus", "Repository\nStatus"]

          if opts[:remarks]
            headings << "Remarks"
            remarks_counter = 0
            remarks = []
          end

          rows = generate_rows(dependencies, opts)

          # Show Table
          table = Terminal::Table.new headings: headings, rows: rows

          # Show Status
          g_status, g_status_code = global_status(dependencies)

          if opts[:remarks]
            remarks_result = remarks.each_with_index.collect{|remark, idx| "[#{idx + 1}]: #{remark}"}.join("\n")
            output = "#{table}\n#{g_status}\n\nRemarks:\n#{remarks_result}"
          else
            output = "#{table}\n#{g_status}"
          end
          [output, g_status_code]
        end

        # Generate a single row
        def generate_rows(dependencies, opts)
          rows = []
          dependencies.each do |dependency|
            status = status_to_mark(dependency.status)
            chef_status = status_to_mark(dependency.chef_status)
            repomanager_status = status_to_mark(dependency.repomanager_status)

            name = dependency.name.dup
            name = name.red if dependency.status == :'error'

            row = [
              name,
              dependency.requirement,
              dependency.version_used,
              dependency.latest_chef,
              dependency.latest_metadata_repomanager,
              { value: status, alignment: :center },
              { value: chef_status, alignment: :center },
              { value: repomanager_status, alignment: :center }
            ]

            if opts[:remarks]
              remarks_idx, remarks_counter = remarks_indices(dependency.remarks, remarks_counter)
              remarks.push(*dependency.remarks)
              row << remarks_idx
            end

            rows << row
          end
          rows
        end

        def global_status(dependencies)
          code = :'up-to-date'
          status = "Status: up-to-date (#{TICK_MARK})".green

          # Note that global :error-chef is not possible since there would be at least
          # one :error
          if dependencies.any? { |dep| dep.status == :'error' }
            status = "Status: error (#{X_MARK})".red
            code = :error
          elsif dependencies.any? { |dep| dep.repomanager_status == :'error-repomanager' }
            status = "Status: error-repomanager (#{X_MARK})".yellow
            code = :'error-repomanager'
          elsif dependencies.any? { |dep| dep.repomanager_status == :'warning-outofdate-repomanager' }
            status = "Status: warning-outofdate-repomanager (#{ESCLAMATION_MARK * 2})".light_red
            code = :'warning-outofdate-repomanager'
          elsif dependencies.any? { |dep| dep.status == :'warning-req' }
            status = "Status: warning-req (#{ESCLAMATION_MARK})".yellow
            code = :'warning-req'
          elsif dependencies.any? { |dep| dep.repomanager_status == :'warning-mismatch-repomanager' }
            status = "Status: warning-mismatch-repomanager (#{ESCLAMATION_MARK})".light_red
            code = :'warning-mismatch-repomanager'
          elsif dependencies.any? { |dep| dep.chef_status == :'warning-chef' }
            status = "Status: warning-chef (#{INFO_MARK})".blue
            code = :'warning-chef'
          end

          [status, code]
        end

        # Return the indices of the remarks
        def remarks_indices(remarks, remarks_counter)
          end_counter = remarks_counter + remarks.count

          return [((remarks_counter + 1)..end_counter).to_a.join(', '), end_counter] unless remarks.empty?
          return ['', end_counter]
        end

        # Given a status return a mark
        def status_to_mark(status)
          case status
          when :'up-to-date'
            return TICK_MARK.green
          when /error.*/
            return X_MARK.red
          when /warning-req/
            return ESCLAMATION_MARK.bold.yellow
          when /warning-chef/
            return INFO_MARK.bold.blue
          when /warning-mismatch-repomanager/
            return ESCLAMATION_MARK.bold.light_red
          when /warning-outofdate-repomanager/
            return (ESCLAMATION_MARK * 2).bold.light_red
          else
            return ''.white
          end
        end
      end
    end

    # Return Kitchen's status in JSON format
    class JSONReport
      class << self
        def generate(dependencies)
          JSON.pretty_generate(dependencies_hash(dependencies))
        end

        # Converts the dependency objects to JSON object
        #
        # @param dependencies [Array<Dependency>] list of cookbook dependency objects
        #
        def dependencies_hash(dependencies)
          {}.tap do |hash|
            dependencies.each do |dependency|
              hash[dependency.name] = dependency.to_hash
            end
          end
        end
      end
    end
  end
end
