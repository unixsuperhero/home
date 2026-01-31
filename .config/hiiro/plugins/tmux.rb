#!/usr/bin/env ruby

module Tmux
  def self.load(hiiro)
    attach_methods(hiiro)
  end

  def self.attach_methods(hiiro)
    hiiro.instance_eval do
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
