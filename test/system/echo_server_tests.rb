require 'assert'
require 'test/support/echo_server'

# The intent of this test is to be sure the dat-tcp can be used as intended.
# That is, that a custom server can be defined, started, stopped and will
# respond as expected.

class EchoServerTests < Assert::Context
  include EchoServer::Helpers

  desc "defining a custom Echo Server"
  setup do
    @server = EchoServer.new(:logger => TEST_LOGGER)
  end
  teardown do
    @server.stop true
  end

  should "have started a separate thread for running the server" do
    @server.listen('127.0.0.1', 56789)
    thread = @server.start
    thread.join(JOIN_SECONDS)

    assert_instance_of Thread, thread
    assert_true thread.alive?
  end

  should "be able to connect, send messages and have them echoed back" do
    self.start_server(@server, '127.0.0.1', 56789) do
      begin
        client = nil
        assert_nothing_raised do
          client = TCPSocket.open('127.0.0.1', 56789)
        end

        client.write('Test')
        client.close_write
        response = client.read if IO.select([client], nil, nil, 1)

        assert_equal "Test", response
      ensure
        client.close rescue false
      end
    end
  end

end
