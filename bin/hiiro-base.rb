#!/usr/bin/env ruby

require 'pry'

class Hiiro
  def self.init(*args)
    bin = File.basename($0)
    new(bin, *args)
  end

  attr_reader :bin, :original_args, :handlers

  def initialize(bin, *original_args)
    @bin = bin
    @original_args = original_args
    @handlers = {}
  end

  def run
    if runnable?
      runnable.run(*args)
    end
  end

  def runnable
    @runnable ||= proc {
      if subcmd
        if matching_bins.count == 1
          Bin.new(matching_bins.first)
        elsif matching_subcommands.length == 1
          Handler.new(handler)
        end
      end
    }.call
  end

  def runnable?
    !runnable.nil?
  end

  def matching_bins
    @matching_bins ||= Bin.find(bin, subcmd)
  end

  def subcmd
    @subcmd ||= original_args.first.dup
  end

  def args
    @args ||= original_args[1..]
  end

  def add_subcmd(name, &block)
    handlers[name.to_s] = block
  end

  def subcommands
    @subcommands ||= handlers.keys
  end

  def handler
    matches = matching_subcommands
    if matches.length == 1
      @handler ||= handlers.fetch(matches.first.to_s)
    end
  end

  def matching_subcommands
    return if subcmd.nil?

    @matching_subcommands ||= proc {
      matches = subcommands.select { |k| k[/^#{subcmd}/i] }
      matches.map(&:to_sym)
    }.call
  end

  class Bin
    def self.find(bin, subcmd)
      paths = ENV['PATH'].split(?:).uniq
      paths.flat_map { |path|
        prefix = [bin, ?-, subcmd, ?*].join
        glob = File.join(path, prefix)
        matches = Dir.glob(glob)

        matches.select { |new_bin|
          basename = File.basename(new_bin)
          basename.match?(/^#{bin}-#{subcmd}[^-]*$/)
        }
      }.uniq
    end

    attr_reader :bin

    def initialize(bin)
      @bin = bin
    end

    def run(*args)
      system(bin, *args)
    end
  end

  class Handler
    attr_reader :handler
    
    def initialize(handler)
      @handler = handler
    end

    def run(*args)
      handler.call(*args)
    end
  end
end
