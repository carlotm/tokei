# frozen_string_literal: true

require 'bundler/inline'
require "prism"

gemfile do
  source "https://rubygems.org"
  gem "enumerable-statistics", "~> 2.0.8"
end

module Tokei
  class Parser < Prism::Visitor
    def initialize
      @definitions = []
    end

    def run
      each_file { store(it).then { parse(it).then { analyze(it) } } }
      report
    end

    def visit_def_node(node)
      @definitions << Definition.new(@file, node)
      super
    end

    private

      def each_file(&)
        Dir.glob("**/*.rb", flags: File::FNM_DOTMATCH, &)
      end

      def store(file)
        @file = file
      end

      def parse(file)
        Prism.parse_file(file).value
      end

      def analyze(node)
        node.accept self
      end

      def report
        @definitions.sort!
        @definitions.reverse_each.first(10).each { puts it }
      end
  end

  class Definition
    def initialize(file, node)
      @file = file
      @node = node
    end

    def name
      @node.name.to_s
    end

    def line
      @node.start_line
    end

    def length
      @node.end_line - @node.start_line
    end

    def <=>(other)
      case
      when length < other.length then -1
      when length == other.length then 0
      when length > other.length then 1
      end
    end

    def to_s
      "#{name.ljust(40)} #{length.to_s.rjust(4)} #{@file}:#{line}"
    end
  end
end

Tokei::Parser.new.run
