#!/usr/bin/env ruby

require 'pry'
require 'open3'
require 'digest/sha1'

class Directory
  def self.temp_cd(dir, &block)
    pwd = Dir.pwd
    Dir.chdir(dir)
    block.call
    Dir.chdir(pwd)
  end

  def self.all_subfiles(path)
    Dir.glob File.join(path, '**/*')
  end

  def self.subdirs(path)
    Dir.glob File.join(path, '*', '')
  end

  def self.all_subdirs(path)
    dirs = Dir.glob File.join(path, '**', '*/')

    regex = /#{path}\/*/
    dirs.map do |subdir|
      subdir.sub(regex, '')
    end
  end

  def self.dir_tree(path, depth=0)
    subdirs(path).each do |subdir|
      lpad = '  ' * depth
      puts format('%s%s/', lpad, File.basename(subdir))

      dir_tree(subdir, depth + 1)
    end
  end
end

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
      success = runnable.run(*args)

      exit 1 unless success
    end
  end

  def runnable
    @runnable ||= proc {
      if subcmd
        if matching_bins.count == 1
          Bin.new(matching_bins.first)
        elsif exact_match = match_exact_bin
          Bin.new(exact_match)
        else
          Handler.new(handler)
        end
      end
    }.call
  end

  def runnable?
    !runnable.nil?
  end

  def help
    puts 'Possible Subcommands:'
    subcommands.sort.each do |s|
      puts format('  %s', s)
    end
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

  def add_default(&block)
    handlers['DEFAULT'] = block
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
    elsif matches.length > 1
      @handler ||= handlers.fetch(match_exact_subcommand)
    end
  end

  def match_exact_subcommand
    return if subcmd.nil?

    @match_exact_subcommand ||= subcommands.find { |k| k == subcmd }
  end

  def match_exact_bin
    matching_bins.find { |bin| File.basename(bin) == exact_bin_name }
  end

  def exact_bin_name
    @exact_bin_name = "#{bin}-#{subcmd}"
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

  class Args
    attr_reader :raw_args

    def initialize(*raw_args)
      @raw_args = raw_args
    end

    def flags
      @flags ||= proc {
        raw_args.select { |arg|
          arg.match?(/^-[^-]/)
        }.flat_map { |arg|
          arg.sub(/^-/, '').chars
        }
      }.call
    end

    def flag?(flag)
      flags.include?(flag)
    end

    def flag_value(flag)
      found_flag = false
      raw_args.each do |arg|
        if found_flag
          return arg
        end

        if arg.match?(/^-\w*#{flag}/)
          found_flag = true
        end
      end

      nil
    end

    def values
      raw_args.reject do |arg|
        arg.match?(/^-/)
      end
    end
  end
end
