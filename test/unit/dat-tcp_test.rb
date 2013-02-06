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
      assert_nil subject.on_run_called
      assert_nil subject.on_pause_called
      assert_nil subject.on_stop_called
      assert_nil subject.on_halt_called
    end

  end

  class RunTest < BaseTest
    desc "run"
    setup do
      @thread = @server.run('localhost', 45678)
    end
    teardown do
      @server.stop
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
      assert_equal true, subject.on_run_called
      assert_nil subject.on_pause_called
      assert_nil subject.on_stop_called
      assert_equal true, subject.on_halt_called
    end

  end

end
