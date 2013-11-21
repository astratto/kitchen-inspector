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

    class GitlabAccessNotConfiguredError < StandardError; end
    class ChefAccessNotConfiguredError < StandardError; end
    class NotACookbookError < StandardError; end
    class DuplicateCookbookError < StandardError; end
    class UnsupportedReportFormatError < ArgumentError; end

    STATUS_TO_RETURN_CODES = {
        :'up-to-date' => 0,
        :'error' => 100,
        :'error-repomanager' => 101,
        :'error-config' => 110,
        :'error-notacookbook' => 111,
        :'error-reportformat' => 112,
        :'warning-req' => 200,
        :'warning-mismatch-repomanager' => 201,
        :'warning-outofdate-repomanager' => 202,
        :'warning-chef' => 203,
        :'warning-nodependencies' => 204
    }
    STATUS_TO_RETURN_CODES.default = 1
  end
end