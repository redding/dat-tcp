# ThreadedServer is the main interface for defining a new server. This class
# acts as a base for users to inherit from and handles starting and stopping the
# main server loop. The `serve` method is intended to be overwritten so users
# can define handling connections. The server is responsible for managing the
# main-loop:
#
# 1. Wait for worker
# 1. Accept connection
# 2. Process connection by handing off to worker
#
# Options:
#   `max_workers` - (integer) The maximum number of workers for processing
#                   connections. More threads causes more concurrency but also
#                   more overhead. This defaults to 4 workers.
#   `logging`     - (boolean) Whether the server should log processing messages.
#                   These are normally when started, stopped and when a new
#                   connection occurs. Defaults to true.
#   `logger`      - (logger) The logger to use when logging messages. Defaults
#                   to an instance of ruby's logger class.
#
require 'socket'
require 'thread'

require 'threaded_server/logger'
require 'threaded_server/workers'
require 'threaded_server/version'

class ThreadedServer
  attr_reader :host, :port, :workers, :logger

  LISTEN_TIMEOUT = 1

  def initialize(host, port, options = nil)
    options ||= {}
    @host, @port = [ host, port ]
    @thread = nil
    options[:max_workers] ||= 4
    options[:logging] = true if !options.has_key?(:logging)
    @logger = ThreadedServer::Logger.new(options[:logger], {
      :logging => options[:logging],
      :name    => self.name
    })
    @workers = ThreadedServer::Workers.new(options[:max_workers], self.logger)
  end

  def start
    if !self.running?
      @shutdown = false
      !!self.start_server_thread
    else
      false
    end
  end

  def stop
    @shutdown = self.running? ? true : false
  end

  def join_thread(limit = nil)
    @thread.join(limit) if self.running?
  end

  def running?
    !!@thread
  end

  # This method should be overwritten to handle new connections
  def serve(socket)
  end

  def name
    "#{self.class}|#{self.host}:#{self.port}"
  end

  protected

  def start_server_thread
    @tcp_server = TCPServer.new(self.host, self.port)
    @thread = Thread.new{ self.work_loop }
  end

  # Notes:
  # * If the server has been shutdown, then `accept_connection` will return
  #   `nil` always. This will exit the loop and begin shutting down the server.
  def work_loop
    self.logger.info("Starting...")
    while !@shutdown
      self.workers.wait_for_available
      connection = self.accept_connection
      self.workers.process(connection){|client| self.serve(client) } if connection
    end
  rescue Exception => exception
    self.logger.info("Exception occurred, stopping server!")
  ensure
    self.shutdown_server(exception)
  end

  # This method is a retry-loop waiting for a new connection. If a connection is
  # not ready, `accept_nonblock` will raise an exception (`Errno::EWOULDBLOCK`)
  # instead of blocking (`accept` will block waiting for an exception). When an
  # exception occurs, we use `IO.select` with a small timeout. This will either
  # return when the connection is 'ready' (i.e. there is a new connection), or
  # when the timeout runs out. At this point, we loop by retrying accepting
  # a connection. If `IO.select` returned because the connection was ready, then
  # `accept_nonblock` will pick up the connection and return it. Otherwise, the
  # loop continues.
  #
  # Notes:
  # * If the server has been shutdown this will return `nil` always.
  def accept_connection
    return if @shutdown
    @tcp_server.accept_nonblock
  rescue Errno::EAGAIN, Errno::EWOULDBLOCK, Errno::ECONNABORTED, Errno::EPROTO, Errno::EINTR
    IO.select([ @tcp_server ], nil, nil, LISTEN_TIMEOUT)
    retry
  end

  # Notes:
  # * Stopping the workers is a graceful shutdown. It will let them each finish
  #   processing by joining their threads.
  def shutdown_server(exception)
    self.logger.info("Stopping...")
    @tcp_server.close rescue false
    self.logger.info("  letting any running workers finish...")
    self.workers.finish
    @thread = nil
    self.logger.info("Stopped")
    if exception
      self.logger.error("#{exception.class}: #{exception.message}")
      self.logger.error(exception.backtrace.join("\n"))
    end
  end

end
