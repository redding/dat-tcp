require 'dat-tcp'

module EchoServer
  def self.new(*args)
    DatTCP::Server.new(*args) do |socket|
      socket.write(socket.read)
    end
  end

  module Helpers

    def start_server(server, *args)
      begin
        pid = fork do
          server.listen(*args)
          trap("TERM"){ server.stop }
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

