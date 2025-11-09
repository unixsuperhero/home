#!/usr/bin/env ruby

module Project
  def self.load(hiiro)
    hiiro.log "Plugin loaded: #{name}"

    hiiro.load_plugin(Tmux)
    attach_methods(hiiro)
    add_subcommands(hiiro)
  end

  def self.add_subcommands(hiiro)
    hiiro.instance_eval do
      add_subcmd(:project) do |project_name|
        re = /#{project_name}/i

        matches = project_dirs.select{|proj, path| proj.match?(re) }

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

          start_tmux_session(name)
        when 1
          name, path = matches.first

          puts "changing dir: #{path}"
          Dir.chdir(path)

          start_tmux_session(name)
        when (2..)
          puts "ERROR: Multiple matches found"
          puts
          puts "Matches:"
          matches.each { |name, path|
            puts format("  %s: %s", name, path)
          }
        end
      end
    end
  end

  def self.attach_methods(hiiro)
    hiiro.instance_eval do
      def project_dirs
        Dir.glob(File.join(Dir.home, 'proj', '*/')).map { |path|
          [File.basename(path), path]
        }.to_h
      end
    end
  end
end
