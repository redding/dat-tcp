require 'assert'

class ThreadedServer

  class BaseTest < Assert::Context
    desc "ThreadedServer"
    setup do
      @server = ThreadedServer.new('localhost', 8000, {
        :logging => false,
        :ready_timeout => 0
      })
    end
    subject{ @server }

    should have_instance_methods :host, :port, :workers, :logger, :tcp_server, :thread,
      :start, :stop, :join_thread, :running?, :serve, :name, :ready_timeout

    should "return an instance of ThreadedServer::Workers with #workers" do
      assert_instance_of ThreadedServer::Workers, subject.workers
    end
    should "return an instance of ThreadedServer::Logger with #logger" do
      assert_instance_of ThreadedServer::Logger, subject.logger
    end
    should "return nil with #tcp_server and #thread" do
      assert_nil subject.tcp_server
      assert_nil subject.thread
    end
    should "return false with #running?" do
      assert_equal false, subject.running?
    end
  end

  class StartedTest < BaseTest
    desc "started"
    setup do
      @server.start
    end
    teardown do
      @server.stop
    end

    should "return true with #running?" do
      assert_equal true, subject.running?
    end
    should "have created an instance of a TCP Server" do
      assert_instance_of TCPServer, subject.tcp_server
      assert_nothing_raised do
        socket = TCPSocket.new(subject.host, subject.port)
        socket.close
      end
    end
    should "have started a thread for running the TCP Server" do
      assert_instance_of Thread, subject.thread
      assert subject.thread.alive?
    end
  end

  class StoppedTest < StartedTest
    desc "and then stopped"
    setup do
      @server.stop
    end

    should "return false with #running?" do
      assert_equal false, subject.running?
    end
    should "have stopped the tcp server" do
      assert_instance_of TCPServer, subject.tcp_server
      assert subject.tcp_server.closed?
    end
    should "have unset the thread" do
      assert_nil subject.thread
    end
  end

end
