$LOAD_PATH.push File.expand_path('../..', __FILE__)

require 'benchmark'
require 'dat-tcp'
require 'dat-worker-pool/locked_object'
require 'bench/setup'

class BenchServerRunner
  include BenchRunner

  def initialize(options = {})
    output_file_path = if ENV['SERVER_OUTPUT_FILE']
      File.expand_path(ENV['SERVER_OUTPUT_FILE'])
    else
      ROOT_PATH.join('bench/server_report.txt')
    end
    @output_file = File.open(output_file_path, 'w')

    @processing_times = DatWorkerPool::LockedArray.new

    @total_time   = nil
    @average_time = nil
    @min_time     = nil
    @max_time     = nil
  end

  def run
    bench_server = DatTCP::Server.new(Worker, {
      :logger        => LOGGER,
      :worker_params => {
        :processing_times => @processing_times
      }
    })

    ["QUIT", "INT", "TERM"].each do |name|
      Signal.trap(name){ bench_server.stop }
    end

    bench_server.listen(*IP_AND_PORT)
    bench_server.start.join

    output "Server statistics\n"
    if !(benchmarks = @processing_times.values).empty?
      total_time = benchmarks.inject(0){ |s, n| s + n }
      @total_time   = round_and_display(total_time)
      @average_time = round_and_display(total_time / benchmarks.size)
      @min_time     = round_and_display(benchmarks.min)
      @max_time     = round_and_display(benchmarks.max)

      size = [@total_time, @average_time, @min_time, @max_time].map(&:size).max
      output "Total Time:   #{@total_time.rjust(size)}ms"
      output "Average Time: #{@average_time.rjust(size)}ms"
      output "Min Time:     #{@min_time.rjust(size)}ms"
      output "Max Time:     #{@max_time.rjust(size)}ms"
    else
      output "  No requests received"
    end

    output "\n"
  end

  class Worker
    include DatTCP::Worker

    def work!(socket)
      benchmark = Benchmark.measure{ socket.write(socket.read) }
      params[:processing_times].push(benchmark.real)
    ensure
      socket.close rescue false
    end
  end

end

BenchServerRunner.new.run
