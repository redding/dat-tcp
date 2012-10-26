require 'assert'

class DatTCP::Logger

  class BaseTest < Assert::Context
    desc "DatTCP::Logger"
    setup do
      @spy_logger = SpyLogger.new
      @logger = DatTCP::Logger.new
    end
    subject{ @logger }

    should have_instance_methods :info, :error, :real_logger
  end

  class NullLoggerTest < BaseTest
    desc "null_logger"
    setup do
      @logger = DatTCP::Logger.null_logger
    end

    should "return nil with #real_logger" do
      assert_nil subject.real_logger
    end
    should "not raise any exceptions using #info or #error" do
      assert_nothing_raised do
        subject.info("test")
        subject.error("test")
      end
    end
  end

  class PassedLoggerTest < BaseTest
    desc "with passed logger"
    setup do
      @logger = DatTCP::Logger.new(@spy_logger)
    end

    should "return the fake logger with #real_logger" do
      assert_equal @spy_logger, subject.real_logger
    end
    should "call info and error on the real logger with #info or #error" do
      subject.info("test")
      subject.error("test")

      assert_includes 'test', @spy_logger.info_messages
      assert_includes 'test', @spy_logger.error_messages
    end
  end

  class DefaultLoggerTest < BaseTest
    desc "building a default logger"
    setup do
      @logger = DatTCP::Logger.new(nil)
    end

    should "return an instance of ruby's Logger with #real_logger" do
      assert_instance_of Logger, subject.real_logger
    end
  end

end
