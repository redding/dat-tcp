class EchoServer
  include DatTCP::Server

  def serve(socket)
    message = socket.gets("\n")
    socket.puts(message)
  end

  module Helpers

    def start_server(server)
      begin
        pid = fork do
          trap("TERM"){ server.stop }
          server.start
          server.join_thread
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

