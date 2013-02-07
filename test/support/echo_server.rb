class EchoServer
  include DatTCP::Server

  def serve(socket)
    socket.write(socket.read)
  end

  module Helpers

    def start_server(server, *args)
      begin
        pid = fork do
          trap("TERM"){ server.stop }
          server.run(*args).join
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

