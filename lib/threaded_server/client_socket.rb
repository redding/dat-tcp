# Threaded server's client socket is a light wrapper to a socket. It provides
# some convenience methods for working with sockets but proxies most of it's
# methods to the socket.
#
class ThreadedServer

  class ClientSocket
    attr_reader :socket

    def initialize(socket)
      @socket = socket
    end

    def read(bytes)
      self.socket.recvfrom(bytes.to_i).first
    end

    # Notes:
    # * Experienced some problems with `write` hanging clients. Using `print`
    #   seemed to clear this up.
    def write(message)
      self.socket.print(message)
    end

    def method_missing(method, *args, &block)
      self.socket.__send__(method, *args, &block)
    end

    def respond_to?(method)
      super || self.socket.respond_to?(method)
    end

  end

end
