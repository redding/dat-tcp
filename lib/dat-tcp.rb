require 'dat-worker-pool'
require 'ostruct'
require 'socket'
require 'thread'

require 'dat-tcp/version'
require 'dat-tcp/logger'

module DatTCP

  module Server

    attr_reader :logger

    def initialize(config = nil)
      config = OpenStruct.new(config || {})
      @backlog_size     = config.backlog_size     || 1024
      @debug            = config.debug            || false
      @min_workers      = config.min_workers      || 2
      @max_workers      = config.max_workers      || 4
      @ready_timeout    = config.ready_timeout    || 1
      @shutdown_timeout = config.shutdown_timeout || 15

      @logger = DatTCP::Logger.new(@debug)

      check_configuration

      @tcp_server       = nil
      @work_loop_thread = nil
      @worker_pool      = nil
      set_state :stop
    end

    # Socket Options:
    # * SOL_SOCKET   - specifies the protocol layer the option applies to.
    #                  SOL_SOCKET is basic socket options (as opposed to
    #                  something like IPPROTO_TCP for TCP socket options).
    # * SO_REUSEADDR - indicates that the rules used in validating addresses
    #                  supplied in a bind(2) call should allow reuse of local
    #                  addresses. This will allow us to re-bind to a port if we
    #                  were shutdown and started right away. This will still
    #                  throw an "address in use" if a socket is active on the
    #                  port.

    def listen(*args)
      build_server_method = if args.size == 2
        :new
      elsif args.size == 1
        :for_fd
      else
        raise InvalidListenArgsError.new
      end
      set_state :listen
      run_hook 'on_listen'
      @tcp_server = TCPServer.send(build_server_method, *args)

      @tcp_server.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
      run_hook 'configure_tcp_server', @tcp_server

      @tcp_server.listen(@backlog_size)
    end

    def run(client_file_descriptors = nil)
      raise NotListeningError.new if !self.listening?
      set_state :run
      run_hook 'on_run'
      @work_loop_thread = Thread.new{ work_loop(client_file_descriptors) }
    end

    def pause(wait = true)
      set_state :pause
      run_hook 'on_pause'
      wait_for_shutdown if wait
    end

    def stop(wait = true)
      set_state :stop
      run_hook 'on_stop'
      wait_for_shutdown if wait
    end

    def halt(wait = true)
      set_state :halt
      run_hook 'on_halt'
      wait_for_shutdown if wait
    end

    def stop_listening
      @tcp_server.close rescue false
      @tcp_server = nil
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
      !!@work_loop_thread
    end

    def serve(socket)
      self.serve!(socket)
    ensure
      socket.close rescue false
    end

    # This method should be overwritten to handle new connections
    def serve!(socket)
    end

    # Hooks

    def on_listen
    end

    def configure_tcp_server(tcp_server)
    end

    def on_run
    end

    def on_pause
    end

    def on_stop
    end

    def on_halt
    end

    def inspect
      reference = '0x0%x' % (self.object_id << 1)
      "#<#{self.class}:#{reference}".tap do |inspect_str|
        inspect_str << " @state=#{@state.inspect}"
        if self.listening?
          port, ip = @tcp_server.addr[1, 2]
          inspect_str << " @ip=#{ip.inspect} @port=#{port.inspect}"
        end
        inspect_str << " @work_loop_status=#{@work_loop_thread.status.inspect}" if self.running?
        inspect_str << ">"
      end
    end

    protected

    def work_loop(client_file_descriptors = nil)
      self.logger.info "Starting work loop..."
      pool_args = [ @min_workers, @max_workers, @debug ]
      @worker_pool = DatWorkerPool.new(*pool_args){|socket| serve(socket) }
      self.enqueue_file_descriptors(client_file_descriptors || [])
      while @state.run?
        @worker_pool.add_work self.accept_connection
      end
      self.logger.info "Stopping work loop..."
      shutdown_worker_pool if !@state.halt?
    rescue Exception => exception
      self.logger.error "Exception occurred, stopping server!"
      self.logger.error "#{exception.class}: #{exception.message}"
      self.logger.error exception.backtrace.join("\n")
    ensure
      close_connection if !@state.pause?
      clear_thread
      self.logger.info "Stopped work loop"
    end

    def enqueue_file_descriptors(file_descriptors)
      file_descriptors.each do |file_descriptor|
        @worker_pool.add_work TCPSocket.for_fd(file_descriptor)
      end
    end

    # An accept-loop waiting for new connections. Will wait for a connection
    # (up to `ready_timeout`) and accept it. `IO.select` with the timeout
    # allows the server to be responsive to shutdowns.
    def accept_connection
      while @state.run?
        return @tcp_server.accept if self.connection_ready?
      end
    end

    def connection_ready?
      !!IO.select([ @tcp_server ], nil, nil, @ready_timeout)
    end

    def shutdown_worker_pool
      self.logger.info "Shutting down worker pool, letting it finish..."
      @worker_pool.shutdown(@shutdown_timeout)
    end

    def close_connection
      self.logger.info "Closing TCP server connection..."
      self.stop_listening
    end

    def clear_thread
      @work_loop_thread = nil
    end

    def wait_for_shutdown
      @work_loop_thread.join if @work_loop_thread
    end

    def check_configuration
      if @min_workers > @max_workers
        self.logger.warn "The minimum number of workers (#{@min_workers}) " \
                         "is greater than " \
                         "the maximum number of workers (#{@max_workers})."
      end
    end

    def run_hook(method, *args)
      self.send(method, *args)
    end

    def set_state(name)
      @state = State.new(name)
    end

    class State < String

      def initialize(value)
        super value.to_s
      end

      [ :listen, :run, :stop, :halt, :pause ].each do |name|
        define_method("#{name}?"){ self.to_sym == name }
      end

    end

  end

  class InvalidListenArgsError < ArgumentError

    def initialize
      super "invalid arguments, must be either a file descriptor or an ip and port"
    end

  end

  class NotListeningError < RuntimeError

    def initialize
      super "`listen` must be called before calling `run`"
    end

  end

end
