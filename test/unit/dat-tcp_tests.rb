require 'assert'
require 'dat-tcp'

require 'dat-worker-pool/worker_pool_spy'
require 'test/support/tcp_server_spy'

module DatTCP

  class UnitTests < Assert::Context
    desc "DatTCP::Server"
    setup do
      @min_workers = 1
      @max_workers = 1
      @shutdown_timeout = 1
      options = {
        :min_workers => @min_workers,
        :max_workers => @max_workers,
        :shutdown_timeout => @shutdown_timeout
      }
      @server = DatTCP::Server.new(options){ |s| }
    end
    subject{ @server }

    should have_imeths :listen, :start
    should have_imeths :pause, :stop, :halt, :stop_listen
    should have_imeths :listening?, :running?
    should have_imeths :ip, :port, :file_descriptor
    should have_imeths :client_file_descriptors

    should "not know it's ip, port, file descriptor or client file descriptors" do
      assert_nil subject.ip
      assert_nil subject.port
      assert_nil subject.file_descriptor
      assert_equal [], subject.client_file_descriptors
    end

    should "not be connected or running by default" do
      assert_equal false, subject.listening?
      assert_equal false, subject.running?
    end

    should "raise an argument error when listen is called with no arguments" do
      assert_raises(ArgumentError){ subject.listen }
      assert_raises(ArgumentError){ subject.listen(1, 2, 3) }
    end

    should "raise an exception when start is called without calling listen" do
      assert_raises(DatTCP::NotListeningError){ subject.start }
    end

  end

  class ListenAndRunningTests < UnitTests
    setup do
      @tcp_server_spy = TCPServerSpy.new.tap do |server|
        @server_ip     = server.ip
        @server_port   = server.port
        @server_fileno = server.fileno
      end
      @worker_pool_spy = DatWorkerPool::WorkerPoolSpy.new

      ::TCPServer.stubs(:new).tap do |s|
        s.with(@server_ip, @server_port)
        s.returns(@tcp_server_spy)
      end
      ::TCPServer.stubs(:for_fd).tap do |s|
        s.with(@server_fileno)
        s.returns(@tcp_server_spy)
      end
      DatWorkerPool.stubs(:new).tap do |s|
        s.with(@min_workers, @max_workers)
        s.returns(@worker_pool_spy)
      end
      IOSelectStub.clients_unavailable(@tcp_server_spy, 1)
    end
    teardown do
      @server.stop(true) rescue false
      IOSelectStub.remove
      DatWorkerPool.unstub(:new)
      ::TCPServer.unstub(:for_fd)
      ::TCPServer.unstub(:new)
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
      assert_equal true,  subject.listening?
      assert_equal false, subject.running?
    end

    should "have it's TCPServer listening" do
      assert @tcp_server_spy.listening
      assert_equal 1024, @tcp_server_spy.backlog_size
    end

    should "set the TCPServer's Socket::SO_REUSEADDR option to true" do
      option = @tcp_server_spy.socket_options.detect do |opt|
        opt.level == Socket::SOL_SOCKET && opt.name == Socket::SO_REUSEADDR
      end
      assert_equal true, option.value
    end

    should "allow setting socket options on the TCPServer by passing a block" do
      subject.listen(@server_ip, @server_port) do |tcp_server|
        tcp_server.setsockopt(::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY, true)
      end
      option = @tcp_server_spy.socket_options.detect do |opt|
        opt.level == Socket::IPPROTO_TCP && opt.name == Socket::TCP_NODELAY
      end
      assert_equal true, option.value
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
      assert_equal true,  subject.listening?
      assert_equal false, subject.running?
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

    should "be listening and running?" do
      assert_equal true, subject.listening?
      assert_equal true, subject.running?
    end

  end

  class WorkLoopWithWorkTests < ListenAndRunningTests
    desc "when started and a client has connected"
    setup do
      @client = FakeSocket.new
      @tcp_server_spy.connected_sockets << @client
      IOSelectStub.clients_available(@tcp_server_spy, 1)
      @server.listen(@server_ip, @server_port)
      @thread = @server.start
    end

    should "accept connections and add them to the worker pool" do
      assert_includes @client, @worker_pool_spy.work_items
    end

    should "allow retrieving the client sockets file descriptors" do
      assert_includes @client.fileno, subject.client_file_descriptors
    end

    should "client file descriptors should still be accessible after its paused" do
      @server.pause true
      assert_includes @client.fileno, subject.client_file_descriptors
    end

  end

  class StartWithClientFileDescriptorTests < ListenAndRunningTests
    desc "when start is called and given client file descriptors"
    setup do
      @clients = [*1..2].map do |n|
        client = FakeSocket.new
        TCPSocket.stubs(:for_fd).with(client.fileno).returns(client)
        client
      end
      @server.listen(@server_ip, @server_port)
      @thread = @server.start(@clients.map(&:fileno))
    end
    teardown do
      TCPSocket.unstub(:for_fd)
    end

    should "add the clients to the worker pool" do
      @clients.each{ |c| assert_includes c, @worker_pool_spy.work_items }
    end

  end

  class StopTests < ListenAndRunningTests
    desc "when stop is called"
    setup do
      @server.listen(@server_ip, @server_port)
      @thread = @server.start
      @server.stop true
    end

    should "have shutdown the worker pool" do
      assert @worker_pool_spy.shutdown_called
      assert_equal @shutdown_timeout, @worker_pool_spy.shutdown_timeout
    end

    should "have stopped the TCPServer listening" do
      assert_not @tcp_server_spy.listening
    end

    should "stop the work loop thread" do
      assert_not @thread.alive?
    end

    should "not be listening or running" do
      assert_equal false, subject.listening?
      assert_equal false, subject.running?
    end

  end

  class HaltTests < ListenAndRunningTests
    desc "when halt is called"
    setup do
      @server.listen(@server_ip, @server_port)
      @thread = @server.start
      @server.halt true
    end

    should "not have shutdown the worker pool" do
      assert_not @worker_pool_spy.shutdown_called
    end

    should "have stopped the TCPServer listening" do
      assert_not @tcp_server_spy.listening
    end

    should "stop the work loop thread" do
      assert_not @thread.alive?
    end

    should "not be listening or running" do
      assert_equal false, subject.listening?
      assert_equal false, subject.running?
    end

  end

  class PauseTests < ListenAndRunningTests
    desc "when pause is called"
    setup do
      @server.listen(@server_ip, @server_port)
      @thread = @server.start
      @server.pause true
    end

    should "have shutdown the worker pool" do
      assert @worker_pool_spy.shutdown_called
      assert_equal @shutdown_timeout, @worker_pool_spy.shutdown_timeout
    end

    should "not have stopped the TCPServer listening" do
      assert @tcp_server_spy.listening
    end

    should "stop the work loop thread" do
      assert_not @thread.alive?
    end

    should "be listening but not running" do
      assert_equal true, subject.listening?
      assert_equal false, subject.running?
    end

  end

  module IOSelectStub
    # Stub IO.select to behave how it does for 2 scenarios: clients have
    # connected and are available OR clients haven't connected and aren't
    # available

    def self.clients_available(socket, timeout)
      IO.stubs(:select).tap do |s|
        s.with([ socket ], nil, nil, timeout)
        s.returns([ socket ])
      end
    end

    def self.clients_unavailable(socket, timeout)
      IO.stubs(:select).tap do |s|
        s.with([ socket ], nil, nil, timeout)
        s.returns(nil)
      end
    end

    def self.remove
      IO.unstub(:select)
    end
  end

  class FakeSocket
    attr_reader :fileno

    def initialize(fileno = nil)
      @fileno = fileno || rand(999999)
    end
  end

end
