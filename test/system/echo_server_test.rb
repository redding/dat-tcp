# The intent of this test is to be sure the dat-tcp can be used as intended.
# That is, that a custom server can be defined, started, stopped and will
# respond as expected.
#
require 'assert'

class EchoServerTest < Assert::Context
  include EchoServer::Helpers

  desc "defining a custom Echo Server"
  setup do
    @server = EchoServer.new('localhost', 12000, {
      :logging => false,
      :ready_timeout => 0
    })
  end

  should "have started a separate thread for running the server" do
    @server.start

    assert_instance_of Thread, @server.thread
    assert @server.thread.alive?

    @server.stop
  end
  should "be able to connect, send messages and have them echoed back" do
    self.start_server(@server) do
      begin
        client = nil
        assert_nothing_raised do
          client = TCPSocket.open('localhost', 12000)
        end

        client.puts('Test')
        response = client.gets("\n") if IO.select([ client ], nil, nil, 1)

        assert_equal "Test\n", response
      ensure
        client.close rescue false
      end
    end
  end

end
