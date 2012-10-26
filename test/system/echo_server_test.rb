# The intent of this test is to be sure the dat-tcp can be used as intended.
# That is, that a custom server can be defined, started, stopped and will
# respond as expected.
#
require 'assert'

class EchoServer
  include DatTCP::Server

  def serve(client)
    socket = client.socket
    message = socket.gets
    socket.write(message)
  end

end

# Notes:
# * We start the echo server at the beginning of all the tests and stop it after
#   all the tests have run, this keeps the server from having to be started and
#   stopped for every test.
class EchoServerTest < Assert::Context
  desc "defining a custom Echo Server"
  setup_once do
    ECHO_SERVER = EchoServer.new('localhost', 12000, {
      :logging => false,
      :ready_timeout => 0
    })
    ECHO_SERVER.start
  end
  teardown_once do
    ECHO_SERVER.stop
  end
  subject{ ECHO_SERVER }

  should "have started a separate thread for running the server" do
    assert_instance_of Thread, subject.thread
    assert subject.thread.alive?
  end
  should "be able to connect, send messages and have them echoed back" do
    message = 'Test'
    client = TCPSocket.open('localhost', 12000)
    client.puts(message)

    response = client.gets if IO.select([ client ], nil, nil, 1)
    assert_equal "#{message}\n", response

    client.close
  end

end
