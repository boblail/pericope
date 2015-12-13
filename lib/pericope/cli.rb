require 'pericope'
require 'cli/base'

class Pericope
  class CLI



    ALLOWED_COMMANDS = %w{help normalize parse substitute reverse-substitute usage}



    def self.run(command, *args)
      if ALLOWED_COMMANDS.member?(command)
        command = command.gsub(/-/, '_').to_sym
        CLI.new(*args).send(command)
      else
        CLI.new(*args).usage
      end
    end



    def help
      print <<-HELP

Glossary

  pericope        A Bible reference (e.g. Romans 3:6-11)
  verse ID        An integer that uniquely identifies a Bible verse

      HELP
    end



    def normalize
      begin
        pericope = Pericope.new(input)
        print pericope.to_s
      rescue
        print $!.to_s
      end
    end



    def parse
      begin
        pericope = Pericope.new(input)
        print pericope.to_a.join("\n")
      rescue
        print $!.to_s
      end
    end



    def substitute
      begin
        print Pericope.sub(input)
      rescue
        print $!.to_s
      end
    end



    def reverse_substitute
      begin
        print Pericope.rsub(input)
      rescue
        print $!.to_s
      end
    end



    def usage
      print <<-USAGE

Usage

  pericope [Command] [Input]

Commands

  help                Prints more information about pericope
  normalize           Accepts a pericope and returns a properly-formatted pericope
  parse               Accepts a pericope and returns a list of verse IDs
  substitute          Accepts a block of text and replaces all pericopes in the text with verse IDs
  reverse-substitute  Accepts a block of text and replaces collections of verse IDs with pericopes
  usage               Prints this message

      USAGE
    end



  private



    def initialize(*args)
      @options = extract_options!(*args)
      @input = args.first
      @input = $stdin.read if $stdin.stat.pipe?
    end



    attr_reader :options, :input



    def extract_options!(*args)
      {} # No options accepted yet
    end



  end
end
