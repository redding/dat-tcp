require 'benchmark'
require 'dat-tcp'

module Bench

  class Server
    include DatTCP::Server

    attr_reader :processing_times

    def initialize(*args)
      super
      @times_mutex = Mutex.new
      @processing_times = []
    end

    def serve(socket)
      benchmark = Benchmark.measure do
        socket.write(socket.read)
      end
      @times_mutex.synchronize{ @processing_times << benchmark.real }
    end

  end

end
