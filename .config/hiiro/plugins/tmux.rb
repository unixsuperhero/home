#!/usr/bin/env ruby

module Tmux
  def self.load(hiiro)
    hiiro.log "Plugin loaded: #{name}"

    attach_methods(hiiro)
    add_subcommands(hiiro)
  end

  def self.add_subcommands(hiiro)
    hiiro.add_subcmd(:cd) do |project_name|
      re = /#{project_name}/i

      matches = hiiro.project_dirs.select{|proj, path| proj.match?(re) }

      puts matches_one: matches
      if matches.count > 1
        matches = matches.select{|name, path| name == project_name }
      end

      puts matches_two: matches
      case matches.count
      when 0
        name = 'proj'
        path = File.join(Dir.home, 'proj')

        unless Dir.exist?(path)
          puts "Error: #{path.inspect} does not exist"
          exit 1
        end

        puts "changing dir: #{path}"
        Dir.chdir(path)

        hiiro.start_tmux_session(name)
      when 1
        name, path = matches.first

        puts "changing dir: #{path}"
        Dir.chdir(path)

        hiiro.start_tmux_session(name)
      when (2..)
        puts "ERROR: Multiple matches found"
        puts
        puts "Matches:"
        matches.each { |name, path|
          puts format("  %s: %s", name, path)
        }
      end
    end

    hiiro.add_subcmd(:session) do |session_name|
      start_tmux_session(session_name)
    end
  end

  def self.attach_methods(hiiro)
    hiiro.instance_eval do
      def project_dirs
        Dir.glob(File.join(Dir.home, 'proj', '*/')).map { |path|
          [File.basename(path), path]
        }.to_h
      end

      def start_tmux_session(session_name)
        session_name = session_name.to_s

        unless system('tmux', 'has-session', '-t', session_name)
          system('tmux', 'new', '-d', '-A', '-s', session_name)
        end

        if ENV['TMUX']
          system('tmux', 'switchc', '-t', session_name)
        elsif ENV['NVIM']
          puts "Can't attach to tmux inside a vim terminal"
        else
          system('tmux', 'new', '-A', '-s', session_name)
        end
      end
    end
  end
end
