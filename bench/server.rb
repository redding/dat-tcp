$LOAD_PATH.push File.expand_path('../..', __FILE__)

require 'benchmark'
require 'dat-tcp'
require 'bench/runner'

module Bench

  class Server

    attr_reader :processing_times

    def initialize(*args)
      @server = DatTCP::Server.new(*args){ |s| serve(s) }
      @times_mutex = Mutex.new
      @processing_times = []
    end

    def start(*args)
      @server.listen(*args)
      @server.start.join
    end

    def stop
      @server.stop
    end

    def serve(socket)
      benchmark = Benchmark.measure{ socket.write(socket.read) }
      @times_mutex.synchronize{ @processing_times << benchmark.real }
    end

  end

  class ServerRunner < Bench::Runner

    def initialize(options = {})
      options[:output] ||= File.expand_path("../server_report.txt", __FILE__)
      super(options)
    end

    def run_server
      GC.disable
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

Bench::ServerRunner.new.run_server
