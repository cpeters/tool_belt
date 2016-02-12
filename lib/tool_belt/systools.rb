require 'English'
require 'open3'

module ToolBelt
  class SysTools

    attr_reader :commit

    def initialize(args = {})
      @commit = args.fetch(:commit, false)
    end

    def execute(command, silence_errors = false)
      if @commit
        syscall(command, silence_errors)
      else
        puts "[noop] #{command}"
        return "", true
      end
    end

    private

    def syscall(*cmd, silence_errors)
      puts cmd
      stdout, stderr, status = Open3.capture3(*cmd)
      if status.success?
        return stdout.slice!(1..-(1 + $INPUT_RECORD_SEPARATOR.size)), status.success? # strip trailing eol
      else
        unless silence_errors
          puts "ERROR: #{stdout}" unless stdout.empty?
          puts "ERROR: #{stderr}" unless stderr.empty?
          status.success?
        end
      end
    end

  end
end
