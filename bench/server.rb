require 'benchmark'
require 'dat-tcp'

module Bench

  TIME_MODIFIER = 10 ** 4

  def self.setup
    @root = File.expand_path('../..', __FILE__)
    FileUtils.mkdir_p(File.join(@root, 'tmp'))
    @pid_file = File.join(@root, 'tmp', 'pid')
  end

  def self.start_server(host, port)
    self.setup
    File.open(@pid_file, 'w'){|f| f.write(Process.pid.to_s) }
    server = Bench::Server.new(host, port)
    [ "QUIT", "INT", "TERM" ].each do |name|
      Signal.trap(name) do
        puts "signal received, allow #{DatTCP::LISTEN_TIMEOUT} second(s) for server to stop"
        server.stop
      end
    end
    server.start
    server.join_thread
  end

  def self.stop_server
    self.setup
    pid = File.read(@pid_file).to_i
    Process.kill("QUIT", pid)
  end

  class Server
    include DatTCP::Server

    def initialize(*args)
      super
      @mutex = Mutex.new
      @processing_times = []
    end

    def serve(client)
      self.logger.info("Request Received")
      benchmark = Benchmark.measure do
        received = client.read("Test".bytesize)
        self.logger.info("  got:     #{received.inspect}")
        message = "Hello World"
        self.logger.info("  sending: #{message.inspect}")
        client.write(message)
      end
      time_taken = ((benchmark.real * 1000.to_f) * TIME_MODIFIER).to_i / TIME_MODIFIER.to_f
      @mutex.synchronize{ @processing_times << time_taken }
      self.logger.info("Done (#{time_taken}ms)")
    end

    def stop
      super
      self.logger.info("Server statistics")
      total_time = @processing_times.inject(0){|s, n| s + n }
      average_time = total_time / @processing_times.size
      average_time = (average_time * TIME_MODIFIER).to_i / TIME_MODIFIER.to_f
      total_time = (total_time * TIME_MODIFIER).to_i / TIME_MODIFIER.to_f
      self.logger.info("Average Time: #{average_time}ms")
      self.logger.info("Total Time: #{total_time}ms")
    end

  end

end
