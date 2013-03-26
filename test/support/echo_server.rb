require 'dat-tcp'

class EchoServer
  include DatTCP::Server

  def serve(socket)
    socket.write(socket.read)
    socket.close_write
  end

  module Helpers

    def start_server(server, *args)
      begin
        pid = fork do
          server.listen(*args)
          trap("TERM"){ server.stop }
          server.run.join
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

