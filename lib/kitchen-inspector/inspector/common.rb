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
    class ConfigurationError < StandardError; end
    class RepositoryManagerError < ConfigurationError; end

    class ChefAccessNotConfiguredError < StandardError; end
    class NotACookbookError < StandardError; end
    class DuplicateCookbookError < StandardError; end
    class UnsupportedReportFormatError < ArgumentError; end

    # Graphical marks
    TICK_MARK = "\u2714"
    X_MARK = "\u2716"
    ESCLAMATION_MARK = "!"
    INFO_MARK = "i"
    INDENT_MARK = "\u203A"
    QUESTION_MARK = "?"

    STATUSES = {
      :up_to_date => TICK_MARK,
      :err_req => X_MARK,
      :err_repo => X_MARK,
      :err_chef => X_MARK,
      :warn_req => ESCLAMATION_MARK,
      :warn_chef => INFO_MARK,
      :warn_mismatch_repo => ESCLAMATION_MARK,
      :warn_outofdate_repo => (ESCLAMATION_MARK * 2),
      :warn_notunique_repo => QUESTION_MARK
    }
    STATUSES.default = ' '

    STATUS_TO_RETURN_CODES = {
      :up_to_date => 0,
      :err_req => 100,
      :err_repo => 101,
      :err_config => 102,
      :err_notacookbook => 103,
      :err_reportformat => 104,
      :warn_req => 200,
      :warn_mismatch_repo => 201,
      :warn_outofdate_repo => 202,
      :warn_chef => 203
    }
    STATUS_TO_RETURN_CODES.default = 1
  end
end