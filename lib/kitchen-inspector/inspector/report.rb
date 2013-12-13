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
    class Report
      class << self
        # Generates the status of dependent cookbooks in specified format
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

          rows, remarks = generate_rows(dependencies, opts)

          # Show Table
          table = Terminal::Table.new headings: headings, rows: rows

          # Show Status
          g_status, g_status_code = StatusAnalyzer.global_status(dependencies)

          if opts[:remarks]
            remarks_result = remarks.each_with_index.collect{|remark, idx| "[#{idx + 1}]: #{remark}"}.join("\n")
            output = "#{table}\n#{g_status}\n\nRemarks:\n#{remarks_result}"
          else
            output = "#{table}\n#{g_status}"
          end
          [output, g_status_code]
        end

        # Generate table rows
        def generate_rows(dependencies, opts)
          rows = []
          remarks = []

          dependencies.select{|d| d.parents.empty?}.each do |dependency|
            dep_rows, dep_remarks = display_child(dependency, remarks.size, 0, opts)

            rows.push(*dep_rows)
            remarks.push(*dep_remarks)
          end
          [rows, remarks]
        end

        def display_child(dependency, remarks_counter, level, opts)
          row, remarks = generate_row(dependency, remarks_counter, level, opts)
          remarks_counter += remarks.size
          children_rows = []
          children_remarks = []

          dependency.dependencies.each do |child|
            child_row, child_remarks = display_child(child, remarks_counter, level + 1, opts)
            remarks_counter += child_remarks.size

            children_rows.push(*child_row)
            children_remarks.push(*child_remarks)
          end


          [[row, *children_rows], [remarks, children_remarks].flatten]
        end

        def indent_name(name, level)
          level > 0 ? "#{(' ' * level) + INDENT_MARK} #{name}" : name
        end

        # Generate a single row and its remarks
        def generate_row(dependency, remarks_counter, level, opts)
          row_remarks = []

          status = StatusAnalyzer.status_to_mark(dependency.status)
          chef_status = StatusAnalyzer.status_to_mark(dependency.chef[:status])
          repomanager_status = StatusAnalyzer.status_to_mark(dependency.repomanager[:status])

          name = indent_name(dependency.name.dup, level)
          name = name.red if dependency.status == :err_req

          row = [
            name,
            dependency.requirement,
            dependency.chef[:version_used],
            dependency.chef[:latest_version],
            dependency.repomanager[:latest_metadata],
            { value: status, alignment: :center },
            { value: chef_status, alignment: :center },
            { value: repomanager_status, alignment: :center }
          ]

          if opts[:remarks]
            remarks_idx, remarks_counter = remarks_indices(dependency.remarks, remarks_counter)
            row_remarks.push(*dependency.remarks)
            row << remarks_idx
          end

          [row, row_remarks]
        end

        # Return the indices of the remarks
        def remarks_indices(remarks, remarks_counter)
          end_counter = remarks_counter + remarks.count

          return [((remarks_counter + 1)..end_counter).to_a.join(', '), end_counter] unless remarks.empty?
          return ['', end_counter]
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
