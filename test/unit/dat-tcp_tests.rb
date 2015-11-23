require 'assert'
require 'dat-tcp'

require 'dat-tcp/worker'
require 'dat-worker-pool/worker'
require 'dat-worker-pool/worker_pool_spy'
require 'test/support/tcp_server_spy'

class DatTCP::Server

  class UnitTests < Assert::Context
    desc "DatTCP::Server"
    setup do
      @server_class = DatTCP::Server
    end
    subject{ @server_class }

    should "know its default backlog size" do
      assert_equal 1024, DEFAULT_BACKLOG_SIZE
    end

    should "know its default shutdown timeout" do
      assert_equal 15, DEFAULT_SHUTDOWN_TIMEOUT
    end

    should "know its default number of workers" do
      assert_equal 2, DEFAULT_NUM_WORKERS
    end

    should "raise an argument error if given an invalid worker class" do
      assert_raises(ArgumentError){ @server_class.new(Module.new) }
      assert_raises(ArgumentError){ @server_class.new(Class.new) }
      worker_class = Class.new{ include DatWorkerPool::Worker }
      assert_raises(ArgumentError){ @server_class.new(worker_class) }
    end

  end

  class InitTests < UnitTests
    desc "when init"
    setup do
      @signal_reader, @signal_writer = IO.pipe
      Assert.stub(IO, :pipe){ [@signal_reader, @signal_writer] }

      @wp_spy = nil
      Assert.stub(DatWorkerPool, :new) do |*args|
        @wp_spy = DatWorkerPool::WorkerPoolSpy.new(*args)
      end

      @worker_class = Class.new do
        include DatTCP::Worker
        def work!(socket); socket.close rescue false; end
      end
      @options = {
        :num_workers      => Factory.integer,
        :shutdown_timeout => Factory.integer,
        :worker_params    => { Factory.string => Factory.string }
      }
      @server = @server_class.new(@worker_class, @options)
    end
    subject{ @server }

    should have_imeths :listen, :start
    should have_imeths :pause, :stop, :halt, :stop_listen
    should have_imeths :listening?, :running?
    should have_imeths :ip, :port, :file_descriptor
    should have_imeths :client_file_descriptors

    should "not know it's ip, port, file descriptor" do
      assert_nil subject.ip
      assert_nil subject.port
      assert_nil subject.file_descriptor
    end

    should "know its client file descriptors" do
      assert_equal [], subject.client_file_descriptors
    end

    should "not be connected or running by default" do
      assert_false subject.listening?
      assert_false subject.running?
    end

    should "build a worker pool" do
      assert_not_nil @wp_spy
      assert_equal @worker_class,            @wp_spy.worker_class
      assert_equal @options[:num_workers],   @wp_spy.num_workers
      assert_equal @options[:worker_params], @wp_spy.worker_params
      assert_false @wp_spy.start_called
    end

    should "default its number of workers" do
      @options.delete(:num_workers)
      server = @server_class.new(@worker_class, @options)

      assert_equal DEFAULT_NUM_WORKERS, @wp_spy.num_workers
    end

    should "raise an argument error when listen is called with invalid args" do
      assert_raises(ArgumentError){ subject.listen }
      assert_raises(ArgumentError){ subject.listen(1, 2, 3) }
    end

  end

  class ListenAndRunningTests < InitTests
    setup do
      @tcp_server_spy = TCPServerSpy.new.tap do |server|
        @server_ip     = server.ip
        @server_port   = server.port
        @server_fileno = server.fileno
      end
      @io_select_stub = IOSelectStub.new(@tcp_server_spy, @signal_reader)

      Assert.stub(::TCPServer, :new).with(@server_ip, @server_port){ @tcp_server_spy }
      Assert.stub(::TCPServer, :for_fd).with(@server_fileno){ @tcp_server_spy }
      @io_select_stub.set_nothing_on_inputs
    end
    teardown do
      @io_select_stub.set_data_on_signal_pipe
      @server.stop(true) rescue false
    end

  end

  class ListenTests < ListenAndRunningTests
    desc "when listen is called"
    setup do
      @server.listen(@server_ip, @server_port)
    end

    should "know it's ip, port and file descriptor" do
      assert_equal @tcp_server_spy.ip,     subject.ip
      assert_equal @tcp_server_spy.port,   subject.port
      assert_equal @tcp_server_spy.fileno, subject.file_descriptor
    end

    should "be listening but not running" do
      assert_true  subject.listening?
      assert_false subject.running?
    end

    should "have it's TCPServer listening" do
      assert @tcp_server_spy.listening
      assert_equal DEFAULT_BACKLOG_SIZE, @tcp_server_spy.backlog_size
    end

    should "set the TCPServer's Socket::SO_REUSEADDR option to true" do
      option = @tcp_server_spy.socket_options.detect do |opt|
        opt.level == Socket::SOL_SOCKET && opt.name == Socket::SO_REUSEADDR
      end
      assert_true option.value
    end

    should "allow setting socket options on the TCPServer by passing a block" do
      subject.listen(@server_ip, @server_port) do |tcp_server|
        tcp_server.setsockopt(::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY, true)
      end
      option = @tcp_server_spy.socket_options.detect do |opt|
        opt.level == Socket::IPPROTO_TCP && opt.name == Socket::TCP_NODELAY
      end
      assert_true option.value
    end

  end

  class ListenWithFileDescriptorTests < ListenAndRunningTests
    desc "when listen is called with a file descriptor"
    setup do
      @server.listen(@server_fileno)
    end

    should "know it's ip, port and file descriptor" do
      assert_equal @tcp_server_spy.ip,     subject.ip
      assert_equal @tcp_server_spy.port,   subject.port
      assert_equal @tcp_server_spy.fileno, subject.file_descriptor
    end

    should "be listening but not running" do
      assert_true  subject.listening?
      assert_false subject.running?
    end

  end

  class StartTests < ListenAndRunningTests
    desc "when start is called"
    setup do
      @server.listen(@server_ip, @server_port)
      @thread = @server.start
    end

    should "return a thread for running the server" do
      assert_instance_of Thread, @thread
      assert @thread.alive?
    end

    should "start its worker pool" do
      assert_true @wp_spy.start_called
    end

    should "be listening and running?" do
      assert_true subject.listening?
      assert_true subject.running?
    end

  end

  class WorkLoopWithWorkTests < ListenAndRunningTests
    desc "when started and a client has connected"
    setup do
      @client = FakeSocket.new
      @tcp_server_spy.connected_sockets << @client
      @io_select_stub.set_client_on_tcp_server
      @server.listen(@server_ip, @server_port)
      @thread = @server.start
    end

    should "accept connections and add them to the worker pool" do
      assert_includes @client, @wp_spy.work_items
    end

    should "know its client file descriptors" do
      assert_equal [@client.fileno], subject.client_file_descriptors
    end

    should "still know its client file descriptors after its paused" do
      @io_select_stub.set_data_on_signal_pipe
      subject.pause true
      assert_equal [@client.fileno], subject.client_file_descriptors
    end

  end

  class StartWithClientFileDescriptorTests < ListenAndRunningTests
    desc "when start is called and given client file descriptors"
    setup do
      @clients = Factory.integer(3).times.map do |n|
        client = FakeSocket.new
        Assert.stub(TCPSocket, :for_fd).with(client.fileno){ client }
        client
      end
      @server.listen(@server_ip, @server_port)
      @thread = @server.start(@clients.map(&:fileno))
    end

    should "add the clients to the worker pool" do
      @clients.each{ |c| assert_includes c, @wp_spy.work_items }
    end

  end

  class StopTests < ListenAndRunningTests
    desc "when stop is called"
    setup do
      @server.listen(@server_ip, @server_port)
      @thread = @server.start
      @io_select_stub.set_data_on_signal_pipe
      @server.stop true
    end

    should "have shutdown the worker pool" do
      assert @wp_spy.shutdown_called
      assert_equal @options[:shutdown_timeout], @wp_spy.shutdown_timeout
    end

    should "have stopped the TCPServer listening" do
      assert_not @tcp_server_spy.listening
    end

    should "stop the work loop thread" do
      assert_not @thread.alive?
    end

    should "not be listening or running" do
      assert_false subject.listening?
      assert_false subject.running?
    end

  end

  class HaltTests < ListenAndRunningTests
    desc "when halt is called"
    setup do
      @server.listen(@server_ip, @server_port)
      @thread = @server.start
      @io_select_stub.set_data_on_signal_pipe
      @server.halt true
    end

    should "shutdown the worker pool with a 0 second timeout" do
      assert_true @wp_spy.shutdown_called
      assert_equal 0, @wp_spy.shutdown_timeout
    end

    should "have stopped the TCPServer listening" do
      assert_not @tcp_server_spy.listening
    end

    should "stop the work loop thread" do
      assert_not @thread.alive?
    end

    should "not be listening or running" do
      assert_false subject.listening?
      assert_false subject.running?
    end

  end

  class PauseTests < ListenAndRunningTests
    desc "when pause is called"
    setup do
      @server.listen(@server_ip, @server_port)
      @thread = @server.start
      @io_select_stub.set_data_on_signal_pipe
      @server.pause true
    end

    should "have shutdown the worker pool" do
      assert @wp_spy.shutdown_called
      assert_equal @options[:shutdown_timeout], @wp_spy.shutdown_timeout
    end

    should "not have stopped the TCPServer listening" do
      assert @tcp_server_spy.listening
    end

    should "stop the work loop thread" do
      assert_not @thread.alive?
    end

    should "be listening but not running" do
      assert_true  subject.listening?
      assert_false subject.running?
    end

  end

  class IOSelectStub
    # Stub IO.select to behave how it does for 2 scenarios: clients have
    # connected and are available OR clients haven't connected and aren't
    # available

    def initialize(tcp_server, signal_pipe)
      @tcp_server  = tcp_server
      @signal_pipe = signal_pipe
    end

    def set_client_on_tcp_server
      Assert.stub(IO, :select).with([@tcp_server, @signal_pipe]) do
        [ [ @tcp_server ], [], [] ]
      end
    end

    def set_data_on_signal_pipe
      Assert.stub(IO, :select).with([@tcp_server, @signal_pipe]) do
        [ [ @signal_pipe ], [], [] ]
      end
    end

    def set_nothing_on_inputs
      Assert.stub(IO, :select).with([@tcp_server, @signal_pipe]) do
        [ [], [], [] ]
      end
    end
  end

  class FakeSocket
    attr_reader :fileno

    def initialize(fileno = nil)
      @fileno = fileno || rand(999999)
    end
  end

end
