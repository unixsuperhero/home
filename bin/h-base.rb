#!/usr/bin/env ruby

require 'pry'
require 'open3'
require 'json'
require 'digest'
require 'digest/sha1'

DEFAULT_KEY = 'DEFAULT'.freeze

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
  attr_reader :runner

  def initialize(bin, *original_args)
    @bin = bin
    @original_args = original_args
    @handlers = {}
  end

  def run
    success = runnable&.run(*args) || false

    exit 1 unless success
  end

  def runnable
    @runnable ||= lambda {
      if !subcmd && has_default_handler?
        return default_handler
      end

      if matching_bin
        Bin.new(matching_bin)
      elsif matching_subcommand
        Handler.new(matching_subcommand, handlers[matching_subcommand])
      elsif has_default_handler?
        default_handler
      end
    }.call
  end

  def matching_bin
    if matching_bins.count == 1
      matching_bins.first
    else
      matching_bins.find{|bin| bin == [$PROGRAM_NAME, subcmd].join(?-) }
    end
  end

  def matching_subcommand
    if matching_subcommands.count == 1
      matching_subcommands.first
    else
      matching_subcommands.find{|name| name == subcmd }
    end
  end

  def default_handler
    Handler.new(DEFAULT_KEY, handlers[DEFAULT_KEY]) if has_default_handler?
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

  def has_default_handler?
    handlers.key?(DEFAULT_KEY)
  end

  def default_handler?
    runnable? && runnable.default?
  end

  def args
    if default_handler?
      [subcmd, *original_args[1..]]
    else
      original_args[1..]
    end
  end

  def add_default(&block)
    handlers[DEFAULT_KEY] = block
  end

  def add_subcmd(name, &block)
    handlers[name.to_s] = block
  end

  def subcommands
    @subcommands ||= handlers.keys
  end

  def handler
    if runnable?
      @handler ||= runnable
    end
  end

  def default_block
    proc do |*args|
      puts format('ERROR: %s', :no_runnable_found)
      puts
      help
    end
  end

  def matching_subcommands
    @matching_subcommands ||=
      subcommands.select { |k| k[/^#{subcmd}/i] }
  end

  class Bin
    def self.find(bin, subcmd)
      prefix = "#{bin}-#{subcmd}*"
      paths = ENV['PATH'].split(?:).uniq.join(?,)

      relative_glob = "{#{paths}}/#{prefix}"
      relative_matches = Dir.glob(relative_glob)

      relative_matches
    end

    attr_reader :name, :bin

    def initialize(bin)
      @name = File.basename(bin)
      @bin = bin
    end

    def default?
      false
    end

    def run(*args)
      system(runner, *args)
    end
  end

  class Handler
    attr_reader :name, :handler
    
    def initialize(name, handler)
      @name = name
      @handler = handler
    end

    def default?
      @name == DEFAULT_KEY
    end

    def run(*args)
      runner.call(*args)
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
