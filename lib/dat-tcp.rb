require 'dat-worker-pool'
require 'socket'
require 'thread'

require 'dat-tcp/version'
require 'dat-tcp/worker'

module DatTCP

  class Server

    DEFAULT_NUM_WORKERS = 2

    def initialize(worker_class, options = nil)
      if !worker_class.kind_of?(Class) || !worker_class.include?(DatTCP::Worker)
        raise ArgumentError, "worker class must include `#{DatTCP::Worker}`"
      end

      options ||= {}
      @backlog_size     = options[:backlog_size]     || 1024
      @shutdown_timeout = options[:shutdown_timeout] || 15

      @signal_reader, @signal_writer = IO.pipe

      @logger_proxy = if options[:logger]
        LoggerProxy.new(options[:logger])
      else
        NullLoggerProxy.new
      end

      @worker_pool = DatWorkerPool.new(worker_class, {
        :num_workers   => (options[:num_workers] || DEFAULT_NUM_WORKERS),
        :logger        => options[:logger],
        :worker_params => options[:worker_params]
      })

      @tcp_server = nil
      @thread     = nil
      @signal     = Signal.new(:stop)
    end

    def ip
      @tcp_server.addr[3] if self.listening?
    end

    def port
      @tcp_server.addr[1] if self.listening?
    end

    def file_descriptor
      @tcp_server.fileno if self.listening?
    end

    def client_file_descriptors
      @worker_pool.work_items.map(&:fileno)
    end

    def listening?
      !!@tcp_server
    end

    def running?
      !!(@thread && @thread.alive?)
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

    def start(passed_client_fds = nil)
      raise NotListeningError.new unless listening?
      @signal.set :start
      @thread = Thread.new{ work_loop(passed_client_fds) }
    end

    def pause(wait = false)
      @signal_writer.write_nonblock('p')
      wait_for_shutdown if wait
    end

    def stop(wait = false)
      @signal_writer.write_nonblock('s')
      wait_for_shutdown if wait
    end

    def halt(wait = false)
      @signal_writer.write_nonblock('h')
      wait_for_shutdown if wait
    end

    def inspect
      reference = '0x0%x' % (self.object_id << 1)
      "#<#{self.class}:#{reference}".tap do |s|
        s << " @ip=#{ip.inspect} @port=#{port.inspect}"
        s << ">"
      end
    end

    private

    def work_loop(passed_client_fds)
      setup(passed_client_fds)
      accept_client_connections while @signal.start?
    rescue StandardError => exception
      log{ "An error occurred while running the server, exiting" }
      log{ "#{exception.class}: #{exception.message}" }
      (exception.backtrace || []).each{ |l| log{ l } }
    ensure
      teardown
    end

    def setup(passed_client_fds)
      @worker_pool.start
      (passed_client_fds || []).each do |fd|
        @worker_pool.push TCPSocket.for_fd(fd)
      end
    end

    def accept_client_connections
      ready_inputs, _, _ = IO.select([@tcp_server, @signal_reader])

      if ready_inputs.include?(@tcp_server)
        @worker_pool.push @tcp_server.accept
      end

      if ready_inputs.include?(@signal_reader)
        @signal.send @signal_reader.read_nonblock(1)
      end
    end

    def teardown
      unless @signal.pause?
        log{ "Stop listening for connections, closing TCP socket" }
        self.stop_listen
      end

      timeout = @signal.halt? ? 0 : @shutdown_timeout
      @worker_pool.shutdown(timeout)
    ensure
      @thread = nil
    end

    def wait_for_shutdown
      @thread.join if @thread
    end

    def log(&message_block)
      @logger_proxy.log(&message_block)
    end

    class Signal
      def initialize(value)
        @value = value
        @mutex = Mutex.new
      end

      def s; set :stop;  end
      def h; set :halt;  end
      def p; set :pause; end

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

    class LoggerProxy < Struct.new(:logger)
      def log(&message_block)
        self.logger.debug("[DTCP] #{message_block.call}")
      end
    end

    class NullLoggerProxy
      def log(&block); end
    end

  end

  class NotListeningError < RuntimeError
    def initialize
      super "server isn't listening, call `listen` first"
    end
  end

end
