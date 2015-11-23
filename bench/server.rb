$LOAD_PATH.push File.expand_path('../..', __FILE__)

require 'benchmark'
require 'dat-tcp'
require 'dat-worker-pool/locked_object'
require 'bench/runner'

module Bench

  class Worker
    include DatTCP::Worker

    def work!(socket)
      benchmark = Benchmark.measure{ socket.write(socket.read) }
      params[:processing_times].push(benchmark.real)
    ensure
      socket.close rescue false
    end
  end

  class ServerRunner < Bench::Runner

    def initialize(options = {})
      options[:output] ||= File.expand_path("../server_report.txt", __FILE__)
      super(options)

      @processing_times = DatWorkerPool::LockedArray.new
    end

    def run_server
      GC.disable
      host_and_port = HOST_AND_PORT.dup

      bench_server = DatTCP::Server.new(Bench::Worker, {
        :debug         => !!ENV['DEBUG'],
        :worker_params => {
          :processing_times => @processing_times
        }
      })

      ["QUIT", "INT", "TERM"].each do |name|
        Signal.trap(name){ bench_server.stop }
      end

      bench_server.listen(*host_and_port)
      bench_server.start.join

      self.write_report
    end

    def write_report
      output "Server statistics\n"
      if !(benchmarks = @processing_times.values).empty?
        total_time = benchmarks.inject(0){|s, n| s + n }
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

Bench::ServerRunner.new.run_server
