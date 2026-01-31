#!/usr/bin/env ruby

module Project
  def self.load(hiiro)
    hiiro.load_plugin(Tmux)
    attach_methods(hiiro)
    add_subcommands(hiiro)
  end

  def self.add_subcommands(hiiro)
    hiiro.add_subcmd(:project) do |project_name|
      re = /#{project_name}/i

      conf_matches = hiiro.projects_from_config.select{|k,v| k.match?(re) }
      dir_matches = hiiro.project_dirs.select{|proj, path| proj.match?(re) }

      puts(conf_matches:,dir_matches:)
      matches = dir_matches.merge(conf_matches)
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
  end

  def self.attach_methods(hiiro)
    hiiro.instance_eval do
      def project_dirs
        Dir.glob(File.join(Dir.home, 'proj', '*/')).map { |path|
          [File.basename(path), path]
        }.to_h
      end

      def projects_from_config
        projects_file = File.join(Dir.home, '.config/hiiro', 'projects.yml')

        return {} unless File.exist?(projects_file)

        YAML.safe_load_file(projects_file)
      end
    end
  end
end
