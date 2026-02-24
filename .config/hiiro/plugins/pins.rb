#!/usr/bin/env ruby

module Pins
  def self.load(hiiro)
    attach_methods(hiiro)
    add_subcommands(hiiro)
  end

  def self.add_subcommands(hiiro)
    hiiro.add_subcmd(:pin) do |*args|
      pins = hiiro.pins

      case args
      in [] then pins.pins.each {|k,v| puts "#{k} => #{v.inspect}" }
      in ['all'] then pins.pins.each {|k,v| puts "#{k} => #{v.inspect}" }
      in ['get', name] then puts pins.get(name)
      in [name] then puts pins.get(name)
      in ['rm', name] then puts pins.remove_and_save(name)
      in ['remove', name] then puts pins.remove_and_save(name)
      in ['set', name, value] then pins.set_and_save(name, value)
      in [name, value] then pins.set_and_save(name, value)
      in [name, *values] then pins.set_and_save(name, values.join(' '))
      else
        puts "No matching pin subcommand for #{args.inspect}"
      end
    end
  end

  def self.attach_methods(hiiro)
    hiiro.instance_eval do
      def pins
        @pins ||= Pin.new(self)
      end
    end
  end

  class Pin
    attr_reader :hiiro

    def initialize(hiiro) = @hiiro = hiiro

    def get(name)
      pins[find(name)]
    end

    def set(name, value)
      pins[name.to_s] = value
    end

    def set_and_save(name, value)
      set(name, value)
      save_pins
      value
    end

    def search(partial)
      Hiiro::Matcher.by_prefix(pins.keys.map(&:to_s), partial)
    end

    def find(partial)
      search(partial).first&.item
    end

    def find_all(partial)
      search(partial).matches.map(&:item)
    end

    def remove(name)
      result = search(name)

      if result.ambiguous?
        puts "Unable to remove pin.  Multiple matches: #{result.matches.map(&:item).inspect}"
        return
      end

      pin_name = result.match&.item

      pins.delete(pin_name.to_s)
    end

    def remove_and_save(name)
      remove(name)
      save_pins
      pins
    end

    def pin_filename = hiiro.bin_name
    def pin_dir = Hiiro::Config.config_dir('pins').tap {|dir| FileUtils.mkdir_p(dir) }
    def pin_file = File.join(pin_dir, pin_filename)
    def pins
      return @pins if @pins

      unless File.exist?(pin_file)
        File.write(pin_file, YAML.dump({}, stringify_names: true))
      end

      @pins = YAML.safe_load_file(pin_file)
    end

    def save_pins(pins = nil)
      pins = pins || @pins || {}

      File.write(pin_file, YAML.dump(pins, stringify_names: true))
    end

    def pins!
      @pins = nil
      pins
    end
  end
end
