require 'ostruct'
require 'socket'
require 'thread'

module DatTCP; end

require 'dat-tcp/logger'
require 'dat-tcp/worker_pool'
require 'dat-tcp/version'

module DatTCP

  module Server

    # Configuration Options:
    # `backlog_size`  - The number of connections that can be pending. These
    #                   are connections that haven't been 'accepted'.
    # `debug`         - Whether or not the server should output debug
    #                   messages. Otherwise it is silent.
    # `min_workers`   - The minimum number of threads that the server should
    #                   have running for handling connections.
    # `max_workers`   - The maximum number of threads that the server will
    #                   spin up to handle connections.
    # `ready_timeout` - The number of seconds the server will wait for a new
    #                   connection. This controls the "responsiveness" of the
    #                   server; how fast it will perform checks, like
    #                   detecting it's been stopped.

    attr_reader :logger

    def initialize(config = nil)
      config = OpenStruct.new(config || {})
      @backlog_size  = config.backlog_size  || 1024
      @debug         = config.debug         || false
      @min_workers   = config.min_workers   || 2
      @max_workers   = config.max_workers   || 4
      @ready_timeout = config.ready_timeout || 1

      @logger = DatTCP::Logger.new(@debug)

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

    # TODO - allow creating a TCPServer from a filedescriptor
    def listen(ip, port)
      if !self.listening?
        set_state :listen
        run_hook 'on_listen'
        @tcp_server = TCPServer.new(ip, port)
        @tcp_server.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
        # TODO - configure TCPServer hook
        @tcp_server.listen(@backlog_size)
      end
    end

    def run(*args)
      listen(*args)
      set_state :run
      run_hook 'on_run'
      @work_loop_thread = Thread.new{ work_loop }
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

    def listening?
      !!@tcp_server
    end

    def running?
      !!@work_loop_thread
    end

    # This method should be overwritten to handle new connections
    def serve(socket)
    end

    # Hooks

    def on_listen
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

    def work_loop
      self.logger.info "Starting work loop..."
      setup_run
      while @state.run?
        @worker_pool.enqueue_connection self.accept_connection
      end
      self.logger.info "Stopping work loop..."
      graceful_shutdown if !@state.halt?
    rescue Exception => exception
      self.logger.error "Exception occurred, stopping server!"
      self.logger.error "#{exception.class}: #{exception.message}"
      self.logger.error exception.backtrace.join("\n")
    ensure
      close_connection if !@state.pause?
      clear_thread
      self.logger.info "Stopped work loop"
    end

    def setup_run
      min, max = @min_workers, @max_workers
      @worker_pool = DatTCP::WorkerPool.new(min, max, @debug) do |socket|
        self.serve(socket)
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

    def graceful_shutdown
      self.logger.info "Shutting down worker pool, letting it finish..."
      @worker_pool.shutdown
      @worker_pool = nil
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

    def run_hook(method)
      self.send(method)
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

end
