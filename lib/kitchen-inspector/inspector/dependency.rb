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
    # The class that contains information about a dependent cookbook
    class Dependency
      include Comparable

      # The name of the dependency
      attr_reader :name

      # The requirement for the dependency
      attr_reader :requirement

      # Info from Chef Server
      attr_accessor :chef

      # Info from the Repository Manager
      attr_accessor :repomanager

      # The status of the dependency
      attr_accessor :status

      # The dependencies of a cookbook
      attr_accessor :dependencies

      # Remarks field
      attr_accessor :remarks

      # Dependency's parents (if transitive)
      attr_accessor :parents

      def initialize(name, requirement)
        @name = name
        @requirement = requirement
        @chef = {}
        @repomanager = {}
        @status = nil
        @remarks = []
        @dependencies = []
        @parents = []
      end

      def ==(anOther)
        name == anOther.name && requirement == anOther.requirement
      end

      def to_hash
        {}.tap do |hash|
          hash[:name] = name
          hash[:requirement] = requirement
          hash[:status] = status
          hash[:remarks] = remarks
          hash[:dependencies] = dependencies
          hash[:parents] = parents
          hash[:chef] = chef
          hash[:repomanager] = repomanager
        end
      end
    end
  end
end
