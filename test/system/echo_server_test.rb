# The intent of this test is to be sure the dat-tcp can be used as intended.
# That is, that a custom server can be defined, started, stopped and will
# respond as expected.
#
require 'assert'

class EchoServerTest < Assert::Context
  include EchoServer::Helpers

  desc "defining a custom Echo Server"
  setup do
    @server = EchoServer.new({ :ready_timeout => 0.1, :debug => !!ENV['DEBUG'] })
  end

  should "have started a separate thread for running the server" do
    thread = @server.run('localhost', 56789)

    assert_instance_of Thread, thread
    assert thread.alive?

    @server.stop
  end

  should "be able to connect, send messages and have them echoed back" do
    self.start_server(@server, 'localhost', 56789) do
      begin
        client = nil
        assert_nothing_raised do
          client = TCPSocket.open('localhost', 56789)
        end

        client.write('Test')
        client.close_write
        response = client.read if IO.select([ client ], nil, nil, 1)

        assert_equal "Test", response
      ensure
        client.close rescue false
      end
    end
  end

end
