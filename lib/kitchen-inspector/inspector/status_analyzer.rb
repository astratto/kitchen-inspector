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
    class StatusAnalyzer
      class << self
        # Return a global status
        #
        # Note that global :err_chef is not possible since there would
        # be at least one :err that takes precedence
        def global_status(dependencies)
          result = nil
          dependencies.each do |dep|
            status = single_status(dep)

            if status
              result = status
              break
            end
          end

          unless result
            result = {:mark => TICK_MARK, :color => :green, :code => :up_to_date}
          end

          ["Status: #{result[:code]} (#{result[:mark]})".send(result[:color]), result[:code]]
        end

        # Return a dependency local status if different from up-to-date
        def single_status(dep)
          return mark_structure(:err) if dep.status == :err

          return mark_structure(:err_repo) if dep.repomanager[:status] == :err_repo

          return mark_structure(:warn_outofdate_repo) if dep.repomanager[:status] == :warn_outofdate_repo

          return mark_structure(:warn_req) if dep.status == :warn_req

          return mark_structure(:warn_mismatch_repo) if dep.repomanager[:status] == :warn_mismatch_repo

          return mark_structure(:warn_chef) if dep.chef[:status] == :warn_chef

          return mark_structure(:warn_notunique_repo) if dep.repomanager[:status] == :warn_notunique_repo

          nil
        end

        # Given a status return instructions on how to draw it
        def mark_structure(status)
          case status
            when :err, :err_chef
              {:mark => STATUSES[status], :color => :red, :code => status }
            when :err_repo
              {:mark => STATUSES[status], :color => :yellow, :code => status }
            when :warn_outofdate_repo
              {:mark => STATUSES[status], :color => :light_red, :code => status, :style => :bold }
            when :warn_req
              {:mark => STATUSES[status], :color => :yellow, :code => status, :style => :bold }
            when :warn_mismatch_repo
              {:mark => STATUSES[status], :color => :light_red, :code => status, :style => :bold }
            when :warn_chef
              {:mark => STATUSES[status], :color => :blue, :code => status, :style => :bold }
            when :warn_notunique_repo
              {:mark => STATUSES[status], :color => :light_red, :code => status }
            when :up_to_date
              {:mark => STATUSES[status], :color => :green, :code => status }
            else
              raise StandardError, "Unknown status #{status}"
          end
        end

        # Given a status draw a mark
        def status_to_mark(status)
          mark = mark_structure(status)

          result = mark[:mark]
          result = result.send(mark[:style]) if mark[:style]
          result = result.send(mark[:color])
          result
        end
      end
    end
  end
end
