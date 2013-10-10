require 'benchmark'
require 'dat-tcp'

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

end
