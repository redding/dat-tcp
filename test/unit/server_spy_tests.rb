require 'assert'
require 'dat-tcp/server_spy'

require 'dat-tcp'
require 'dat-tcp/worker'

class DatTCP::ServerSpy

  class UnitTests < Assert::Context
    desc "DatTCP::ServerSpy"
    setup do
      @spy_class = DatTCP::ServerSpy
    end
    subject{ @spy_class }

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @worker_class = Class.new{ include DatTCP::Worker }
      @options = {
        :backlog_size     => Factory.integer,
        :shutdown_timeout => Factory.integer,
        :num_workers      => Factory.integer,
        :logger           => TEST_LOGGER,
        :worker_params    => { Factory.string => Factory.string }
      }

      @server_spy = @spy_class.new(@worker_class, @options)
    end
    subject{ @server_spy }

    should have_readers :worker_class
    should have_readers :options, :backlog_size, :shutdown_timeout
    should have_readers :num_workers, :logger, :worker_params
    should have_readers :ip, :port, :file_descriptor
    should have_readers :client_file_descriptors
    should have_readers :waiting_for_pause, :waiting_for_stop, :waiting_for_halt
    should have_accessors :listen_called, :start_called
    should have_accessors :stop_listen_called, :pause_called
    should have_accessors :stop_called, :halt_called
    should have_imeths :listening?, :running?
    should have_imeths :listen, :stop_listen
    should have_imeths :start, :stop, :halt

    should "know its attributes" do
      assert_equal @worker_class,               subject.worker_class
      assert_equal @options,                    subject.options
      assert_equal @options[:backlog_size],     subject.backlog_size
      assert_equal @options[:shutdown_timeout], subject.shutdown_timeout
      assert_equal @options[:num_workers],      subject.num_workers
      assert_equal @options[:logger],           subject.logger
      assert_equal @options[:worker_params],    subject.worker_params

      assert_nil subject.ip
      assert_nil subject.port
      assert_nil subject.file_descriptor
      assert_equal [], subject.client_file_descriptors

      assert_nil subject.waiting_for_pause
      assert_nil subject.waiting_for_stop
      assert_nil subject.waiting_for_halt

      assert_false subject.listen_called
      assert_false subject.stop_listen_called
      assert_false subject.start_called
      assert_false subject.pause_called
      assert_false subject.stop_called
      assert_false subject.halt_called
    end

    should "default its attributes" do
      server_ns = DatTCP::Server

      server_spy = @spy_class.new(@worker_class)
      assert_equal server_ns::DEFAULT_BACKLOG_SIZE,     server_spy.backlog_size
      assert_equal server_ns::DEFAULT_SHUTDOWN_TIMEOUT, server_spy.shutdown_timeout
      assert_equal server_ns::DEFAULT_NUM_WORKERS,      server_spy.num_workers
    end

    should "know if its listening or not" do
      assert_false subject.listening?
      subject.listen(Factory.integer)
      assert_true subject.listening?
      subject.stop_listen
      assert_false subject.listening?
    end

    should "know if its running or not" do
      assert_false subject.running?
      subject.start
      assert_true subject.running?

      subject.pause
      assert_false subject.running?
      subject.pause_called = false

      subject.stop
      assert_false subject.running?
      subject.stop_called = false

      subject.halt
      assert_false subject.running?
    end

    should "set its ip, port and listen flag using `listen`" do
      ip   = Factory.string
      port = Factory.integer

      assert_false subject.listen_called
      subject.listen(ip, port)
      assert_equal ip,   subject.ip
      assert_equal port, subject.port
      assert_true subject.listen_called
    end

    should "set its file descriptor and listen flag using `listen`" do
      fd = Factory.integer

      assert_false subject.listen_called
      subject.listen(fd)
      assert_equal fd, subject.file_descriptor
      assert_true subject.listen_called
    end

    should "set its stop listen flag using `stop_listen`" do
      assert_false subject.stop_listen_called
      subject.stop_listen
      assert_true subject.stop_listen_called
    end

    should "set its client file descriptors and its start flag using `start`" do
      client_fds = [Factory.integer, Factory.integer]

      assert_false subject.start_called
      subject.start(client_fds)
      assert_equal client_fds, subject.client_file_descriptors
      assert_true subject.start_called
    end

    should "set its waiting for pause and pause called flag using `pause`" do
      wait = Factory.boolean

      assert_false subject.pause_called
      subject.pause(wait)
      assert_equal wait, subject.waiting_for_pause
      assert_true subject.pause_called
    end

    should "set its waiting for stop and stop called flag using `stop`" do
      wait = Factory.boolean

      assert_false subject.stop_called
      subject.stop(wait)
      assert_equal wait, subject.waiting_for_stop
      assert_true subject.stop_called
    end

    should "set its waiting for halt and halt called flag using `halt`" do
      wait = Factory.boolean

      assert_false subject.halt_called
      subject.halt(wait)
      assert_equal wait, subject.waiting_for_halt
      assert_true subject.halt_called
    end

  end

end
