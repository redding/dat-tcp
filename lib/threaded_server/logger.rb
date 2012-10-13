# Threaded server's logger class is a wrapper that provides a consistent
# interface for the rest of the gem. Even if logging is turned off, this becomes
# a null logger, just consuming any messages that would be logged. It also
# builds a default logger using ruby's standard logger and configures it
# slightly.
#
require 'logger'

class ThreadedServer

  class Logger

    def initialize(logger = nil, options = nil)
      options ||= {}
      @logger = logger || self.default_logger(options[:name]) if options[:logging]
    end

    [ :info, :error ].each do |name|

      define_method(name) do |message|
        @logger.send(name, message) if @logger
      end

    end

    protected

    def default_logger(name = "ThreadedServer")
      ::Logger.new(STDOUT).tap do |logger|
        logger.progname = "[#{name}]"
        logger.datetime_format = "%m/%d/%Y %H:%M:%S%p "
      end
    end

  end

end
