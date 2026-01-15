#!/usr/bin/env ruby

require 'pry'
require 'open3'
require 'json'
require 'digest'
require 'digest/sha1'

DEFAULT_KEY = 'DEFAULT'.freeze

def overlap?(shorter_string, longer_string)
  longer_string&.to_s.start_with?(shorter_string.to_s) ||
    shorter_string&.to_s.start_with?(longer_string.to_s)
end

def any_overlap?(list, longer_string)
  list.any? { |shorter_string| overlap?(shorter_string, longer_string) }
end

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
    # @handlers = {
    #   DEFAULT: default_block,
    # }.transform_keys(&:to_s)
  end

  def run
    success = runnable&.run(*args) || false

    exit 1 unless success
  end

  def pin_file = File.join(Dir.home, 'pins', exact_bin_name)

  def pins
    return {} unless File.exist?(pin_file)

    @pins || pins!
  end

  def pins!
    @pins = File.readlines(pin_file, chomp: true).each_with_object({}) do |line, h|
      pin, val = line.split(/\s*:\s*/, 2)
      h[pin] = val
    end
  end

  def pin_name(q)
    pins.keys.find { |name| name.start_with?(q) }
  end

  def pin(q)
    name = pin_name(q)
    puts "PIN NAME: #{name.inspect}"

    return nil unless name

    pins[name].tap do |val|
      puts "PIN VALUE: #{val.inspect}"
    end
  end

  def main_dir(pattern, dir_name='carrot')
    format(pattern, dir_name: dir_name || 'carrot')
  end

  def switch_to_tmux_session(session_name)
    if ENV['TMUX'] || ENV['NVIM']
      unless system('tmux', 'has-session', '-t', session_name)
        system('tmux', 'new', '-d', '-A', '-s', session_name)
      end

      system('tmux', 'switchc', '-t', session_name)
    else
      system('tmux', 'new', '-A', '-s', session_name)
    end
  end

  def runnable
    @runnable ||= lambda {
      if subcmd
        return Bin.new(match_exact_bin) if match_exact_bin
        return Bin.new(matching_bins.first) if matching_bins.count == 1
      end

      Handler.new(handler)
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
    handlers[DEFAULT_KEY] = block
  end

  def add_subcmd(*names, &block)
    names.each do |name|
      handlers[name.to_s] = block.dup
    end
  end

  def subcommands
    @subcommands ||= handlers.keys
  end

  def handler
    return @handler if @handler

    matches = matching_subcommands

    if matches.length == 1
      @handler = handlers.fetch(matches.first.to_s)
    elsif matches.length > 1
      @handler = handlers.fetch(match_exact_subcommand)
    else
      @handler = default_block
    end
  end

  def default_block
    proc do |*args|
      puts format('ERROR: %s', :no_runnable_found)
      puts
      help
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
    return [] if subcmd.nil?

    @matching_subcommands ||= proc {
      matches = subcommands.select { |k| k[/^#{subcmd}/i] }
      matches.map(&:to_sym)
    }.call
  end

  class Bin
    def self.find(bin, subcmd)
      exact_matches = find_exact(bin, subcmd)
      relative_matches = find_relative(bin, subcmd)

      all_matches = exact_matches + relative_matches

      all_matches.uniq
    end

    def self.find_relative(bin, subcmd)
      prefix = "#{bin}-#{subcmd}*"
      paths = ENV['PATH'].split(?:).uniq.join(?,)

      relative_glob = "{#{paths}}/#{prefix}"
      relative_matches = Dir.glob(relative_glob)

      relative_matches
    end

    def self.find_exact(bin, subcmd)
      prefix = "#{bin}-#{subcmd}"
      paths = ENV['PATH'].split(?:).uniq.join(?,)

      exact_glob = "{#{paths}}/#{prefix}"
      exact_matches = Dir.glob(exact_glob)

      exact_matches
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
      system(bin, *args)
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
