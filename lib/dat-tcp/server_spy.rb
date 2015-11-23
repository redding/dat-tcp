require 'dat-tcp'
require 'dat-tcp/worker'

module DatTCP

  class ServerSpy

    attr_reader :worker_class
    attr_reader :options, :backlog_size, :shutdown_timeout
    attr_reader :num_workers, :logger, :worker_params
    attr_reader :ip, :port, :file_descriptor
    attr_reader :client_file_descriptors
    attr_reader :waiting_for_pause, :waiting_for_stop, :waiting_for_halt
    attr_accessor :listen_called, :start_called
    attr_accessor :stop_listen_called, :pause_called
    attr_accessor :stop_called, :halt_called

    def initialize(worker_class, options = nil)
      @worker_class = worker_class
      if !@worker_class.kind_of?(Class) || !@worker_class.include?(DatTCP::Worker)
        raise ArgumentError, "worker class must include `#{DatTCP::Worker}`"
      end

      server_ns = DatTCP::Server
      @options          = options || {}
      @backlog_size     = @options[:backlog_size]     || server_ns::DEFAULT_BACKLOG_SIZE
      @shutdown_timeout = @options[:shutdown_timeout] || server_ns::DEFAULT_SHUTDOWN_TIMEOUT
      @num_workers      = (@options[:num_workers]     || server_ns::DEFAULT_NUM_WORKERS).to_i
      @logger           = @options[:logger]
      @worker_params    = @options[:worker_params]

      @ip                      = nil
      @port                    = nil
      @file_descriptor         = nil
      @client_file_descriptors = []

      @waiting_for_pause = nil
      @waiting_for_stop  = nil
      @waiting_for_halt  = nil

      @listen_called      = false
      @stop_listen_called = false
      @start_called       = false
      @pause_called       = false
      @stop_called        = false
      @halt_called        = false
    end

    def listening?
      @listen_called && !@stop_listen_called
    end

    def running?
      @start_called && !(@pause_called || @stop_called || @halt_called)
    end

    def listen(*args)
      case args.size
      when 2
        @ip, @port = args
      when 1
        @file_descriptor = args.first
      end
      @listen_called = true
    end

    def stop_listen
      @stop_listen_called = true
    end

    def start(passed_client_fds = nil)
      @client_file_descriptors = passed_client_fds || []
      @start_called = true
    end

    def pause(wait = false)
      @waiting_for_pause = wait
      @pause_called = true
    end

    def stop(wait = false)
      @waiting_for_stop = wait
      @stop_called = true
    end

    def halt(wait = false)
      @waiting_for_halt = wait
      @halt_called = true
    end

  end

end
