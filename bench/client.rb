require 'benchmark'
require 'socket'

module Bench

  TIME_MODIFIER = 10 ** 4

  def self.run_client(host, port, num)
    benchmarks = []
    number_of_requests = num.to_i.abs > 0 ? num.to_i.abs : 1
    puts "Testing the Benchmark server with #{number_of_requests} request(s)"
    [*1..number_of_requests].each do |index|
      benchmark = Benchmark.measure do
        self.run_request(host, port)
      end
      time_taken = ((benchmark.real * 1000.to_f) * TIME_MODIFIER).to_i / TIME_MODIFIER.to_f
      benchmarks << time_taken
      puts "request ##{index} -> #{time_taken}ms"
    end
    total_time_taken = benchmarks.inject(0){|s, n| s + n }
    puts "all requests run -> #{total_time_taken}"
  end

  def self.run_request(host, port)
    socket = TCPSocket.open(host, port)
    socket.send("Test", 0)
    ready = IO.select([ socket ], nil, nil, 10)
    if ready
      socket.recvfrom("Hello World".bytesize).first
    else
      raise "Timed out waiting for server response"
    end
    socket.close if socket
  end

end
