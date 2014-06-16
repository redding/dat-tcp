$LOAD_PATH.push File.expand_path('../..', __FILE__)

require 'benchmark'
require 'socket'
require 'bench/runner'

module Bench

  class Client

    def initialize(host, port)
      @host, @port = [ host, port ]
    end

    def call(message)
      TCPSocket.open(@host, @port) do |socket|
        socket.write(message)
        socket.close_write
        if IO.select([ socket ], nil, nil, 10)
          socket.read
        else
          raise "Timed out waiting for server response"
        end
      end
    end

  end

  class ClientRunner < Bench::Runner

    def build_report
      GC.disable
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

end
Bench::ClientRunner.new.build_report
