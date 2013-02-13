require 'assert'

module DatTCP

  class BaseTest < Assert::Context
    desc "DatTCP"
    setup do
      @server = TestServer.new({ :ready_timeout => 0 })
    end
    subject{ @server }

    should have_instance_methods :logger
    should have_instance_methods :listen, :run, :pause, :stop, :halt, :stop_listening
    should have_instance_methods :listening?, :running?
    should have_instance_methods :on_listen, :on_run, :on_pause, :on_stop, :on_halt
    should have_instance_methods :serve
    should have_instance_methods :file_descriptor, :connections_file_descriptors

    should "return an instance of DatTCP::Logger::Null with #logger" do
      assert_instance_of DatTCP::Logger::Null, subject.logger
    end

    should "not be listening or running" do
      assert_equal false, subject.listening?
      assert_equal false, subject.running?
    end

  end

  class ListenTest < BaseTest
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

  end

  class RunTest < BaseTest
    desc "run"
    setup do
      @thread = @server.run('localhost', 45678)
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

  class PauseTest < BaseTest
    desc "pause"
    setup do
      @thread = @server.run('localhost', 45678)
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

  class StopTest < BaseTest
    desc "stop"
    setup do
      @thread = @server.run('localhost', 45678)
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

  class HaltTest < BaseTest
    desc "halt"
    setup do
      @thread = @server.run('localhost', 45678)
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

  class FileDescriptorsTest < BaseTest
    desc "file descriptor handling"
    setup do
      @server = TestServer.new({
        :ready_timeout => 0,
        :min_workers   => 0,
        :max_workers   => 0
      })
      @thread = @server.run('localhost', 29384)
      @client_socket = TCPSocket.new('localhost', 29384)
      @thread.join(1) # give the server a chance to queue the connection
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
      server_socket_fileno = subject.connections_file_descriptors.first
      server_socket = TCPSocket.for_fd(server_socket_fileno)

      assert_equal [ 29384, 'localhost' ], server_socket.addr[1, 2]
    end

    should "allow building a DatTCP server file descriptors" do
      subject.pause
      new_server = TestServer.new({ :ready_timeout => 0 })
      new_server.listen(@server.file_descriptor)
      connections = subject.connections_file_descriptors
      thread = new_server.run(connections)
      @server.stop_listening
      value = @client_socket.read if IO.select([ @client_socket ], nil, nil, 2)

      assert_equal 'handled', value

      new_server.stop
      thread.join
    end

  end

end
