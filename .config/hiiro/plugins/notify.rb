#!/usr/bin/env ruby

module Notify
  def self.load(hiiro)
    hiiro.load_plugin(Tmux)
    attach_methods(hiiro)
    add_subcommands(hiiro)
  end

  def self.add_subcommands(hiiro)
    hiiro.add_subcmd(:notify) do |message, link=nil, title=nil, command=nil|
      hiiro.notify(message, title:, link:, command:)
    end
  end

  def self.attach_methods(hiiro)
    hiiro.instance_eval do
      def notify(message, title: nil, link: nil, command: nil)
        args = ['terminal-notifier', '-message', message]
        args += ['-title', title] if title
        args += ['-open', link] if link
        args += ['-execute', command] if command

        system(*args) if system('which', 'terminal-notifier')
      end
    end
  end
end
