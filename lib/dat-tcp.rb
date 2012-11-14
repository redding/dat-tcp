# DatTCP Server module is the main interface for defining a new server. It
# should be mixed in and provides methods for starting and stopping the main
# server loop. The `serve` method is intended to be overwritten so users can
# define handling connections. It's primary loop is:
#
# 1. Wait for worker
# 1. Accept connection
# 2. Process connection by handing off to worker
#
# This is repeated until the server is stopped.
#
# Options:
#   `max_workers`   - (integer) The maximum number of workers for processing
#                     connections. More threads causes more concurrency but also
#                     more overhead. This defaults to 4 workers.
#   `debug`         - (boolean) Whether or not to have the server log debug
#                     messages for when the server starts and stops and when a
#                     client connects and disconnects.
#   `ready_timeout` - (float) The timeout used with `IO.select` waiting for a
#                     connection to occur. This can be set to 0 to not wait at
#                     all. Defaults to 1 (second).
#
require 'logger'
require 'socket'
require 'thread'

module DatTCP; end

require 'dat-tcp/logger'
require 'dat-tcp/workers'
require 'dat-tcp/version'

module DatTCP

  module Server
    attr_reader :host, :port, :workers, :debug, :logger, :ready_timeout
    attr_reader :tcp_server, :thread

    def initialize(host, port, options = nil)
      options ||= {}
      options[:max_workers] ||= 4

      @host, @port = [ host, port ]
      @logger = DatTCP::Logger.new(options[:debug])
      @workers = DatTCP::Workers.new(options[:max_workers], self.logger)
      @ready_timeout = options[:ready_timeout] || 1

      @mutex = Mutex.new
      @condition_variable = ConditionVariable.new
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
      if self.running?
        @shutdown = true
        @mutex.synchronize do
          while self.thread
            @condition_variable.wait(@mutex)
          end
        end
      else
        false
      end
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

    def inspect
      reference = '0x0%x' % (self.object_id << 1)
      "#<#{self.class}:#{reference} @host=#{self.host.inspect} @port=#{self.port.inspect}>"
    end

    protected

    def start_server_thread
      @tcp_server = TCPServer.new(self.host, self.port)
      @mutex.synchronize do
        @thread = Thread.new{ self.work_loop }
      end
    end

    # Notes:
    # * If the server has been shutdown, then `accept_connection` will return
    #   `nil` always. This will exit the loop and begin shutting down the server.
    def work_loop
      self.logger.info("Starting...")
      while !@shutdown
        connection = self.accept_connection
        self.workers.process(connection){|client| self.serve(client) } if connection
      end
    rescue Exception => exception
      self.logger.info("Exception occurred, stopping server!")
    ensure
      self.shutdown_server_thread(exception)
    end

    # This method is a accept-loop waiting for a new connection. It uses
    # `IO.select` with a timeout to wait for a socket to be ready. Once the
    # socket is ready, it calls `accept` and returns the connection. If the
    # server socket doesn't have a new connection waiting, the loop starts over.
    # In the case the server has been shutdown, it will also break out of the
    # loop.
    #
    # Notes:
    # * If the server has been shutdown this will return `nil`.
    def accept_connection
      loop do
        if IO.select([ @tcp_server ], nil, nil, self.ready_timeout)
          return @tcp_server.accept
        elsif @shutdown
          return
        end
      end
    end

    # Notes:
    # * Stopping the workers is a graceful shutdown. It will let them each finish
    #   processing by joining their threads.
    def shutdown_server_thread(exception = nil)
      self.logger.info("Stopping...")
      @tcp_server.close rescue false
      self.logger.info("  letting any running workers finish...")
      self.workers.finish
      self.logger.info("Stopped")
      if exception
        self.logger.error("#{exception.class}: #{exception.message}")
        self.logger.error(exception.backtrace.join("\n"))
      end
      @mutex.synchronize do
        @thread = nil
        @condition_variable.signal
      end
      true
    end

  end

end
