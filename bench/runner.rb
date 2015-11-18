require 'benchmark'

module Bench

  class Runner
    HOST_AND_PORT = ['0.0.0.0', 12000]

    TIME_MODIFIER = 10 ** 4 # 4 decimal places

    def initialize(options = {})
      options[:output] ||= File.expand_path("../report.txt", __FILE__)
      @file = File.open(options[:output], "w")
    end

    protected

    def output(message, puts = true)
      method = puts ? :puts : :print
      self.send(method, message)
      @file.send(method, message)
      STDOUT.flush if method == :print
    end

    def round_and_display(time_in_ms)
      self.display_time(self.round_time(time_in_ms))
    end

    def round_time(time_in_ms)
      (time_in_ms * TIME_MODIFIER).to_i / TIME_MODIFIER.to_f
    end

    def display_time(time)
      integer, fractional = time.to_s.split('.')
      [integer, fractional.ljust(4, '0')].join('.')
    end

  end

end
