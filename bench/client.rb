require 'socket'

module Bench

  class Client

    def initialize(host, port)
      @host, @port = [ host, port ]
    end

    def call(message)
      TCPSocket.open(@host, @port) do |socket|
        socket.write(message)
        socket.close_write
        ready = IO.select([ socket ], nil, nil, 10)
        if ready
          socket.read
        else
          raise "Timed out waiting for server response"
        end
      end
    end

  end

end
