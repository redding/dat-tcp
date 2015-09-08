class TCPServerSpy
  attr_reader :ip, :port, :fileno
  attr_reader :backlog_size, :socket_options
  attr_reader :listening
  attr_accessor :connected_sockets

  def initialize
    @ip     = '127.0.0.1'
    @port   = 45678
    @fileno = 12345
    close
  end

  def addr
    ['family', @port, 'hostname', @ip]
  end

  def setsockopt(level, name, value)
    @socket_options << SocketOption.new(level, name, value)
  end

  def listen(backlog_size)
    @backlog_size = backlog_size
    @listening = true
  end

  def accept
    @connected_sockets.shift
  end

  def close
    @backlog_size      = nil
    @socket_options    = []
    @listening         = false
    @connected_sockets = []
  end

  SocketOption = Struct.new(:level, :name, :value)
end
