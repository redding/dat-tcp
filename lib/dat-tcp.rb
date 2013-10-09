require 'dat-worker-pool'
require 'socket'
require 'thread'

require 'dat-tcp/version'
require 'dat-tcp/logger'

module DatTCP

  class Server

    attr_reader :logger
    private :logger

    def initialize(config = nil, &serve_proc)
      config ||= {}
      @backlog_size     = config[:backlog_size]     || 1024
      @debug            = config[:debug]            || false
      @min_workers      = config[:min_workers]      || 2
      @max_workers      = config[:max_workers]      || 4
      @ready_timeout    = config[:ready_timeout]    || 1
      @shutdown_timeout = config[:shutdown_timeout] || 15
      @serve_proc = serve_proc || raise(ArgumentError, "no block given")

      @logger = DatTCP::Logger.new(@debug)

      @tcp_server       = nil
      @work_loop_thread = nil
      @worker_pool      = nil
      @signal = Signal.new(:stop)
    end

    def ip
      @tcp_server.addr[2] if self.listening?
    end

    def port
      @tcp_server.addr[1] if self.listening?
    end

    def file_descriptor
      @tcp_server.fileno if self.listening?
    end

    def client_file_descriptors
      @worker_pool ? @worker_pool.work_items.map(&:fileno) : []
    end

    def listening?
      !!@tcp_server
    end

    def running?
      !!(@work_loop_thread && @work_loop_thread.alive?)
    end

    def listen(*args)
      @signal.set :listen
      @tcp_server = TCPServer.build(*args)
      raise ArgumentError, "takes ip and port or file descriptor" if !@tcp_server
      yield @tcp_server if block_given?
      @tcp_server.listen(@backlog_size)
    end

    def stop_listen
      @tcp_server.close rescue false
      @tcp_server = nil
    end

    def start(client_file_descriptors = nil)
      raise NotListeningError.new unless listening?
      @signal.set :start
      @work_loop_thread = Thread.new{ work_loop(client_file_descriptors) }
    end

    def pause(wait = false)
      @signal.set :pause
      wait_for_shutdown if wait
    end

    def stop(wait = false)
      @signal.set :stop
      wait_for_shutdown if wait
    end

    def halt(wait = false)
      @signal.set :halt
      wait_for_shutdown if wait
    end

    def inspect
      reference = '0x0%x' % (self.object_id << 1)
      "#<#{self.class}:#{reference}".tap do |s|
        s << " @ip=#{ip.inspect} @port=#{port.inspect}"
        s << " @work_loop_status=#{@work_loop_thread.status.inspect}" if running?
        s << ">"
      end
    end

    private

    def serve(socket)
      @serve_proc.call(socket)
    ensure
      socket.close rescue false
    end

    def work_loop(client_file_descriptors = nil)
      logger.info "Starting work loop..."
      @worker_pool = DatWorkerPool.new(@min_workers, @max_workers) do |socket|
        serve(socket)
      end
      add_client_sockets_from_fds client_file_descriptors
      while @signal.start?
        @worker_pool.add_work accept_connection
      end
      logger.info "Stopping work loop..."
      shutdown_worker_pool unless @signal.halt?
    rescue Exception => exception
      logger.error "Exception occurred, stopping server!"
      logger.error "#{exception.class}: #{exception.message}"
      logger.error exception.backtrace.join("\n")
    ensure
      unless @signal.pause?
        logger.info "Closing TCP server connection"
        stop_listen
      end
      clear_thread
      logger.info "Stopped work loop"
    end

    def add_client_sockets_from_fds(file_descriptors)
      (file_descriptors || []).each do |file_descriptor|
        @worker_pool.add_work TCPSocket.for_fd(file_descriptor)
      end
    end

    def accept_connection
      @tcp_server.accept if connection_ready?
    end

    def connection_ready?
      !!IO.select([ @tcp_server ], nil, nil, @ready_timeout)
    end

    def shutdown_worker_pool
      logger.info "Shutting down worker pool"
      @worker_pool.shutdown(@shutdown_timeout)
    end

    def clear_thread
      @work_loop_thread = nil
    end

    def wait_for_shutdown
      @work_loop_thread.join if @work_loop_thread
    end

    class Signal
      def initialize(value)
        @value = value
        @mutex = Mutex.new
      end

      def set(value)
        @mutex.synchronize{ @value = value }
      end

      def listen?
        @mutex.synchronize{ @value == :listen }
      end

      def start?
        @mutex.synchronize{ @value == :start }
      end

      def pause?
        @mutex.synchronize{ @value == :pause }
      end

      def stop?
        @mutex.synchronize{ @value == :stop }
      end

      def halt?
        @mutex.synchronize{ @value == :halt }
      end
    end

    module TCPServer
      def self.build(*args)
        case args.size
        when 2
          self.new(*args)
        when 1
          self.for_fd(*args)
        end
      end

      def self.new(ip, port)
        configure(::TCPServer.new(ip, port))
      end

      def self.for_fd(file_descriptor)
        configure(::TCPServer.for_fd(file_descriptor))
      end

      # `setsockopt` values:
      # * SOL_SOCKET   - specifies the protocol layer the option applies to.
      #                  SOL_SOCKET is basic socket options (as opposed to
      #                  something like IPPROTO_TCP for TCP socket options).
      # * SO_REUSEADDR - indicates that the rules used in validating addresses
      #                  supplied in a bind(2) call should allow reuse of local
      #                  addresses. This will allow us to re-bind to a port if
      #                  we were shutdown and started right away. This will
      #                  still throw an "address in use" if a socket is active
      #                  on the port.
      def self.configure(tcp_server)
        tcp_server.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
        tcp_server
      end
    end

  end

  class NotListeningError < RuntimeError
    def initialize
      super "server isn't listening, call `listen` first"
    end
  end

end
