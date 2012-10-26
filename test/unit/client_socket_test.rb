require 'assert'

class DatTCP::ClientSocket

  class BaseTest < Assert::Context
    desc "DatTCP::ClientSocket"
    setup do
      @socket = mock()
      @client = DatTCP::ClientSocket.new(@socket)
    end
    subject{ @client }

    should have_instance_methods :read, :write

  end

  class ReadTest < BaseTest
    desc "read"
    setup do
      @num_bytes = 4
      @expected = 'test'
      result = mock()
      result.expects(:first).returns(@expected)
      @socket.expects(:recvfrom).with(@num_bytes).returns(result)
    end

    should "use recvfrom to read from the socket" do
      assert_equal @expected, subject.read(@num_bytes)
    end
  end

  class WriteTest < BaseTest
    desc "write"
    setup do
      @message = 'test'
      @socket.expects(:print).with(@message)
    end

    should "use print to write to the socket" do
      assert_nothing_raised do
        subject.write(@message)
      end
    end
  end

end
