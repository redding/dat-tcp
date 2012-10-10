require 'logger'
require 'socket'
require 'thread'

require 'threaded_server/workers'
require 'threaded_server/version'

class ThreadedServer
  attr_reader :host, :port, :workers

  LISTEN_TIMEOUT = 1

  def initialize(host, port, options = {})
    @host, @port = [ host, port ]
    @thread = nil
    options[:max_workers] ||= 4
    @workers = ThreadedServer::Workers.new(self, options[:max_workers], self.logger)
  end

  def start
    if !self.running?
      @shutdown = false
      self.start_server_thread
      true
    else
      false
    end
  end

  def stop
    if self.running?
      @shutdown = true
    else
      false
    end
  end

  def join
    if self.running?
      @thread.join
    end
  end

  def running?
    !!@thread
  end

  protected

  def log(message)
    self.logger.info("[#{self.class}|#{self.host}:#{self.port}] #{message}")
  end

  def logger
    @logger ||= Logger.new(STDOUT)
  end

  def start_server_thread
    @tcp_server = TCPServer.new(self.host, self.port)
    # TODO not sure why these are reset, may be for certain OS that do strange
    # things with the ports, GServer did it
    @host = @tcp_server.addr[2]
    @port = @tcp_server.addr[1]
    @thread = Thread.new{ self.work_loop }
  end

  def work_loop
    self.log("Starting")
    while !@shutdown
      self.workers.wait_for_available
      client = self.accept_connection
      break if !client
      self.workers.handle(client)
    end
  rescue Exception => exception
    self.log("Exception occurred, stopping server")
  ensure
    self.log("Stopping")
    @tcp_server.close rescue false
    # TODO - should try to gracefully stop workers always?
    self.log("  stopping any running workers...")
    self.workers.stop
    @thread = nil
    self.log("Stopped")
    if exception
      self.logger.error("#{exception.class}: #{exception.message}")
      self.logger.error(exception.backtrace.join("\n"))
    end
  end

  # Notes:
  # * This loops
  def accept_connection
    return if @shutdown
    @tcp_server.accept_nonblock
  rescue Errno::EAGAIN, Errno::EWOULDBLOCK, Errno::ECONNABORTED, Errno::EPROTO, Errno::EINTR
    IO.select([ @tcp_server ], nil, nil, LISTEN_TIMEOUT)
    retry
  end

end
