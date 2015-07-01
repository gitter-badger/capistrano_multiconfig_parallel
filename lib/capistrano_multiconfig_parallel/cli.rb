require_relative './all'

module CapistranoMulticonfigParallel
  # this is the class that will be invoked from terminal , and willl use the invoke task as the primary function.
  class CLI
    def self.start
      if $stdin.isatty
        $stdin.sync = true
      end
      if $stdout.isatty
        $stdout.sync = true
      end
      CapistranoMulticonfigParallel.original_args = ARGV.dup
      CapistranoMulticonfigParallel::Application.new.run
    rescue Interrupt
      `stty icanon echo`
      $stderr.puts 'Command cancelled.'
    rescue => error
      $stderr.puts error
      exit(1)
    end
  end
end
