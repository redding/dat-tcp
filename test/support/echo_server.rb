require 'dat-tcp'

module EchoServer
  def self.new(options = nil)
    DatTCP::Server.new(EchoServer::Worker, options)
  end

  class Worker
    include DatTCP::Worker

    def work!(socket)
      socket.write(socket.read)
    ensure
      socket.close rescue false
    end
  end

  module Helpers

    def start_server(server, *args)
      begin
        pid = fork do
          server.listen(*args)
          trap("TERM"){ server.stop(true) }
          server.start.join
        end
        sleep 0.3 # Give time for the socket to start listening.
        yield
      ensure
        if pid
          Process.kill("TERM", pid)
          Process.wait(pid)
        end
      end
    end

  end

end

