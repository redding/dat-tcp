$LOAD_PATH.push File.expand_path('../..', __FILE__)

require 'benchmark'
require 'scmd'
require 'socket'
require 'bench/setup'

require 'dat-tcp'

class BenchClientRunner
  include BenchRunner

  RUN_BENCH_SERVER        = "bundle exec ruby ./bench/server.rb".freeze
  WAIT_FOR_SERVER_SECONDS = 10

  def initialize
    output_file_path = if ENV['REPORT_OUTPUT_FILE']
      File.expand_path(ENV['REPORT_OUTPUT_FILE'])
    else
      ROOT_PATH.join('bench/report.txt')
    end
    @output_file = File.open(output_file_path, 'w')

    @number_of_requests = ENV['NUM_REQUESTS'] || 10_000

    @total_time   = nil
    @average_time = nil
    @min_time     = nil
    @max_time     = nil
  end

  def run
    output "Running benchmark report..."
    output("\n", false)

    benchmark_making_requests

    output "\n", false

    size = [@total_time, @average_time, @min_time, @max_time].map(&:size).max
    output "Total Time:   #{@total_time.rjust(size)}ms"
    output "Average Time: #{@average_time.rjust(size)}ms"
    output "Min Time:     #{@min_time.rjust(size)}ms"
    output "Max Time:     #{@max_time.rjust(size)}ms"
    output "\n"

    output "\n"
    output "Done running benchmark report"
  end

  def benchmark_making_requests
    cmd = Scmd.new(RUN_BENCH_SERVER)

    output "Making #{@number_of_requests} request(s):"
    benchmarks = []
    begin
      cmd.start
      if !cmd.running?
        raise "failed to start dat-tcp process: #{RUN_BENCH_SERVER.inspect}"
      end

      start_time = Time.now
      loop do
        seconds_waited = Time.now - start_time
        raise "server didn't start" if seconds_waited > WAIT_FOR_SERVER_SECONDS
        begin
          TCPSocket.open(*IP_AND_PORT){ }
          break
        rescue Errno::ECONNREFUSED
          sleep 1
        end
      end

      @number_of_requests.times.each do |n|
        benchmarks << make_request
        output('.', false) if ((n - 1) % 100 == 0)
      end
    ensure
      if cmd.running?
        cmd.kill('TERM')
        cmd.wait(5)
      end
    end

    total_time = benchmarks.inject(0){ |s, n| s + n }
    @total_time   = round_and_display(total_time)
    @average_time = round_and_display(total_time / benchmarks.size)
    @min_time     = round_and_display(benchmarks.min)
    @max_time     = round_and_display(benchmarks.max)

    output("\n", false)
  end

  def make_request
    benchmark = Benchmark.measure do
      begin
        client = Client.new(*IP_AND_PORT)
        response = client.call(ENV['ECHO_MESSAGE'] || 'test')
        if ENV['SHOW_RESPONSE']
          output "Got response:"
          output "  #{response.inspect}"
        end
      rescue StandardError => exception
        output "FAILED -> #{exception.class}: #{exception.message}"
        output exception.backtrace.join("\n")
      end
    end
    benchmark.real * 1000
  end

  class Client
    def initialize(host, port)
      @host, @port = [host, port]
    end

    def call(message)
      TCPSocket.open(@host, @port) do |socket|
        socket.write(message)
        socket.close_write
        if IO.select([socket], nil, nil, 10)
          socket.read
        else
          raise "Timed out waiting for server response"
        end
      end
    end
  end

end

BenchClientRunner.new.run
