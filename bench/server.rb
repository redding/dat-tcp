require 'benchmark'
require 'threaded_server'

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
        puts "signal received, allow #{ThreadedServer::LISTEN_TIMEOUT} second(s) for server to stop"
        server.stop
      end
    end
    server.start
    server.join
  end

  def self.stop_server
    self.setup
    pid = File.read(@pid_file).to_i
    Process.kill("QUIT", pid)
  end

  class Server < ThreadedServer

    def serve(socket)
      self.log("Request Received")
      benchmark = Benchmark.measure do
        received = socket.recvfrom("Test".bytesize).first
        self.log("  got:     #{received.inspect}")
        message = "Hello World"
        self.log("  sending: #{message.inspect}")
        socket.print(message)
      end
      time_taken = ((benchmark.real * 1000.to_f) * TIME_MODIFIER).to_i / TIME_MODIFIER.to_f
      self.log("Done (#{time_taken}ms)")
    end

  end

end
