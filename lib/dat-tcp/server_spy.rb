require 'dat-tcp/logger'

module DatTCP

  class ServerSpy

    attr_reader :ip, :port, :file_descriptor
    attr_reader :client_file_descriptors
    attr_reader :logger
    attr_reader :worker_start_procs, :worker_shutdown_procs
    attr_reader :worker_sleep_procs, :worker_wakeup_procs
    attr_reader :waiting_for_pause, :waiting_for_stop, :waiting_for_halt
    attr_accessor :listen_called, :start_called
    attr_accessor :stop_listen_called, :pause_called
    attr_accessor :stop_called, :halt_called

    attr_accessor :serve_proc

    def initialize
      @ip = nil
      @port = nil
      @file_descriptor = nil
      @client_file_descriptors = []
      @logger = DatTCP::Logger::Null.new

      @worker_start_procs    = []
      @worker_shutdown_procs = []
      @worker_sleep_procs    = []
      @worker_wakeup_procs   = []

      @waiting_for_pause = nil
      @waiting_for_stop = nil
      @waiting_for_halt = nil

      @listen_called = false
      @stop_listen_called = false
      @start_called = false
      @pause_called = false
      @stop_called = false
      @halt_called = false

      @serve_proc = proc{ }
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

    def start(client_file_descriptors = nil)
      @client_file_descriptors = client_file_descriptors || []
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

    def on_worker_start(&block);    @worker_start_procs << block;    end
    def on_worker_shutdown(&block); @worker_shutdown_procs << block; end
    def on_worker_sleep(&block);    @worker_sleep_procs << block;    end
    def on_worker_wakeup(&block);   @worker_wakeup_procs << block;   end

  end

end
