require 'benchmark'

module Bench

  class Runner
    HOST_AND_PORT = [ '0.0.0.0', 12000 ]

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
      [ integer, fractional.ljust(4, '0') ].join('.')
    end

  end



  class ClientRunner < Runner

    def build_report
      output "Running benchmark report..."
      self.make_requests(nil, 10000, false)
      output "Done running benchmark report"
    end

    def make_requests(message, times, show_result = false)
      benchmarks = []

      output "\nMaking #{times} request(s):"
      [*(1..times.to_i)].each do |index|
        benchmark = self.hit_server(message, show_result)
        benchmarks << self.round_time(benchmark.real * 1000.to_f)
        output('.', false) if ((index - 1) % 100 == 0) && !show_result
      end
      output("\n", false)

      total_time = benchmarks.inject(0){|s, n| s + n }
      data = {
        :number_of_requests => times,
        :total_time_taken   => self.round_and_display(total_time),
        :average_time_taken => self.round_and_display(total_time / benchmarks.size),
        :min_time_taken     => self.round_and_display(benchmarks.min),
        :max_time_taken     => self.round_and_display(benchmarks.max)
      }
      size = data.values.map(&:size).max
      output "Total Time:   #{data[:total_time_taken].rjust(size)}ms"
      output "Average Time: #{data[:average_time_taken].rjust(size)}ms"
      output "Min Time:     #{data[:min_time_taken].rjust(size)}ms"
      output "Max Time:     #{data[:max_time_taken].rjust(size)}ms"
      output "\n"
    end

    protected

    def hit_server(message, show_result)
      require 'bench/client'
      Benchmark.measure do
        begin
          client = Bench::Client.new(*HOST_AND_PORT)
          response = client.call(message || 'test')
          if show_result
            output "Got response:"
            output "  #{response.inspect}"
          end
        rescue Exception => exception
          puts "FAILED -> #{exception.class}: #{exception.message}"
          puts exception.backtrace.join("\n")
        end
      end
    end

  end



  class ServerRunner < Runner

    def initialize(options = {})
      options[:output] ||= File.expand_path("../server_report.txt", __FILE__)
      super(options)
    end

    def run_server
      require 'bench/server'
      host_and_port = HOST_AND_PORT.dup
      bench_server = Bench::Server.new({ :debug => !!ENV['DEBUG'] })
      [ "QUIT", "INT", "TERM" ].each do |name|
        Signal.trap(name){ bench_server.stop }
      end
      bench_server.start(*host_and_port)
      self.write_report(bench_server)
    end

    def write_report(server)
      output "Server statistics\n"
      if !(benchmarks = server.processing_times).empty?
        total_time = server.processing_times.inject(0){|s, n| s + n }
        data = {
          :number_of_requests => benchmarks.size,
          :total_time_taken   => self.round_and_display(total_time),
          :average_time_taken => self.round_and_display(total_time / benchmarks.size),
          :min_time_taken     => self.round_and_display(benchmarks.min),
          :max_time_taken     => self.round_and_display(benchmarks.max)
        }
        size = data.values.map(&:size).max
        output "  Total Time:   #{data[:total_time_taken].rjust(size)}ms"
        output "  Average Time: #{data[:average_time_taken].rjust(size)}ms"
        output "  Min Time:     #{data[:min_time_taken].rjust(size)}ms"
        output "  Max Time:     #{data[:max_time_taken].rjust(size)}ms"
      else
        output "  No requests received"
      end
      output "\n"
    end

  end

end
