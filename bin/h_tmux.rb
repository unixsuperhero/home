#!/usr/bin/env ruby

class Tmux
  def self.start_session(session_name)
    session_name = session_name.to_s

    if ENV['TMUX'] || ENV['NVIM']
      unless system('tmux', 'has-session', '-t', session_name)
        system('tmux', 'new', '-d', '-A', '-s', session_name)
      end

      system('tmux', 'switchc', '-t', session_name)
    else
      system('tmux', 'new', '-A', '-s', session_name)
    end
  end
end
