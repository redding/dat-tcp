require 'assert'
require 'dat-tcp/logger'

module DatTCP::Logger

  class BaseTests < Assert::Context
    desc "DatTCP::Logger"
    subject{ DatTCP::Logger }

    should have_instance_methods :new

  end

  class DebugTests < BaseTests
    desc "debug"
    setup do
      @logger = DatTCP::Logger::Debug.new
    end
    subject{ @logger }

    should "be an instance of Logger" do
      assert_instance_of Logger, subject
    end
  end

  class NullTests < BaseTests
    desc "null"
    setup do
      @logger = DatTCP::Logger::Null.new
    end
    subject{ @logger }

    should have_instance_methods :info, :warn, :error, :debug

    should "be an instance of DatTCP::Logger::Null" do
      assert_instance_of DatTCP::Logger::Null, subject
    end
  end

end
