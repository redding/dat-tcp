class TestServer
  include DatTCP::Server

  attr_reader :on_listen_called, :on_run_called, :on_pause_called,
    :on_stop_called, :on_halt_called, :configure_tcp_server_called

  def on_listen
    @on_listen_called = true
  end

  def configure_tcp_server(tcp_server)
    @configure_tcp_server_called = tcp_server
  end

  def on_run
    @on_run_called = true
  end

  def on_pause
    @on_pause_called = true
  end

  def on_stop
    @on_stop_called = true
  end

  def on_halt
    @on_halt_called = true
  end

  def serve(socket)
    socket.write('handled')
  end

end
