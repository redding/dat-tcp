require 'assert'
require 'test/support/test_server'
require 'dat-tcp'

module DatTCP

  class BaseTests < Assert::Context
    desc "DatTCP"
    setup do
      @server = TestServer.new({ :ready_timeout => 0 })
    end
    subject{ @server }

    should have_instance_methods :logger
    should have_instance_methods :listen, :run, :pause, :stop, :halt, :stop_listening
    should have_instance_methods :listening?, :running?
    should have_instance_methods :on_listen, :on_run, :on_pause, :on_stop, :on_halt
    should have_instance_methods :serve, :ip, :port
    should have_instance_methods :file_descriptor, :client_file_descriptors

    should "return an instance of DatTCP::Logger::Null with #logger" do
      assert_instance_of DatTCP::Logger::Null, subject.logger
    end

    should "not be listening or running" do
      assert_equal false, subject.listening?
      assert_equal false, subject.running?
    end

    should "raise an argument error when listen is called with no arguments" do
      assert_raises(DatTCP::InvalidListenArgsError){ subject.listen }
      assert_raises(DatTCP::InvalidListenArgsError){ subject.listen(1, 2, 3) }
    end

    should "raise an exception when run is called without calling listen" do
      assert_raises(DatTCP::NotListeningError){ subject.run }
    end

  end

  class ListenTests < BaseTests
    desc "listen"
    setup do
      @server.listen('localhost', 45678)
    end
    teardown do
      @server.stop_listening
    end

    should "be listening but not running" do
      assert_equal true,  subject.listening?
      assert_equal false, subject.running?
    end

    should "have created an instance of a TCP Server and started listening" do
      assert_nothing_raised do
        socket = TCPSocket.new('localhost', 45678)
        socket.close
      end
    end

    should "have called on_listen but no other hooks" do
      assert_equal true, subject.on_listen_called
      assert_instance_of TCPServer, subject.configure_tcp_server_called
      assert_nil subject.on_run_called
      assert_nil subject.on_pause_called
      assert_nil subject.on_stop_called
      assert_nil subject.on_halt_called
    end

    should "be able to call run after it" do
      assert_nothing_raised{ subject.run }
      assert subject.running?
      subject.pause
    end

    should "allow retrieving it's ip and port" do
      assert_equal 'localhost', subject.ip
      assert_equal 45678,       subject.port
    end

  end

  class RunTests < BaseTests
    desc "run"
    setup do
      @server.listen('localhost', 45678)
      @thread = @server.run
    end
    teardown do
      @server.stop
      @thread.join
    end

    should "return a thread for running the server" do
      assert_instance_of Thread, @thread
      assert @thread.alive?
    end

    should "be listening and running?" do
      assert_equal true, subject.listening?
      assert_equal true, subject.running?
    end

    should "have called on_listen and on_run but no other hooks" do
      assert_equal true, subject.on_listen_called
      assert_instance_of TCPServer, subject.configure_tcp_server_called
      assert_equal true, subject.on_run_called
      assert_nil subject.on_pause_called
      assert_nil subject.on_stop_called
      assert_nil subject.on_halt_called
    end

  end

  class PauseTests < BaseTests
    desc "pause"
    setup do
      @server.listen('localhost', 45678)
      @thread = @server.run
      @server.pause
      @thread.join
    end
    teardown do
      @server.stop_listening
    end

    should "stop the thread" do
      assert !@thread.alive?
    end

    should "be listening but not running" do
      assert_equal true,  subject.listening?
      assert_equal false, subject.running?
    end

    should "have called on_listen, on_run and on_pause but no other hooks" do
      assert_equal true, subject.on_listen_called
      assert_instance_of TCPServer, subject.configure_tcp_server_called
      assert_equal true, subject.on_run_called
      assert_equal true, subject.on_pause_called
      assert_nil subject.on_stop_called
      assert_nil subject.on_halt_called
    end

  end

  class StopTests < BaseTests
    desc "stop"
    setup do
      @server.listen('localhost', 45678)
      @thread = @server.run
      @server.stop
      @thread.join
    end

    should "stop the thread" do
      assert !@thread.alive?
    end

    should "not be listening or running" do
      assert_equal false, subject.listening?
      assert_equal false, subject.running?
    end

    should "have called on_listen, on_run and on_pause but no other hooks" do
      assert_equal true, subject.on_listen_called
      assert_instance_of TCPServer, subject.configure_tcp_server_called
      assert_equal true, subject.on_run_called
      assert_nil subject.on_pause_called
      assert_equal true, subject.on_stop_called
      assert_nil subject.on_halt_called
    end

  end

  class HaltTests < BaseTests
    desc "halt"
    setup do
      @server.listen('localhost', 45678)
      @thread = @server.run
      @server.halt
      @thread.join
    end

    should "stop the thread" do
      assert !@thread.alive?
    end

    should "not be listening or running" do
      assert_equal false, subject.listening?
      assert_equal false, subject.running?
    end

    should "have called on_listen, on_run and on_pause but no other hooks" do
      assert_equal true, subject.on_listen_called
      assert_instance_of TCPServer, subject.configure_tcp_server_called
      assert_equal true, subject.on_run_called
      assert_nil subject.on_pause_called
      assert_nil subject.on_stop_called
      assert_equal true, subject.on_halt_called
    end

  end

  class FileDescriptorsTests < BaseTests
    desc "file descriptor handling"
    setup do
      @server = TestServer.new({
        :ready_timeout => 0,
        :min_workers   => 0,
        :max_workers   => 0
      })
      @server.listen('localhost', 44375)
      @thread = @server.run
      @client_socket = TCPSocket.new('localhost', 44375)
      @thread.join(0.5) # give the server a chance to queue the connection
    end
    teardown do
      @client_socket.close
      @server.stop
      @thread.join
    end

    should "allow getting the TCP server's file descriptor" do
      tcp_server = subject.instance_variable_get("@tcp_server")
      assert_equal tcp_server.fileno, subject.file_descriptor
    end

    should "allow retrieving the connections file descriptors" do
      connections = subject.instance_variable_get("@worker_pool").connections
      assert_equal connections.map(&:fileno), subject.client_file_descriptors
    end

    should "allow building a DatTCP server from file descriptors" do
      @server.pause
      server_file_descriptor = @server.file_descriptor
      client_file_descriptors = @server.client_file_descriptors

      new_server = TestServer.new({ :ready_timeout => 0 })
      new_server.listen(server_file_descriptor)
      thread = new_server.run(client_file_descriptors)

      value = @client_socket.read if IO.select([ @client_socket ], nil, nil, 2)
      assert_equal 'handled', value

      @server.stop_listening
      new_server.stop
      thread.join
    end

  end

end
