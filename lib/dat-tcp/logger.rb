# Threaded server's logger class is a wrapper that provides a consistent
# interface for the rest of the gem. Even if logging is turned off, this becomes
# a null logger, just consuming any messages that would be logged. It also
# builds a default logger using ruby's standard logger and configures it
# slightly.
#
require 'logger'

module DatTCP

  class Logger
    attr_reader :real_logger

    def initialize(logger = nil, options = nil)
      options ||= {}
      @real_logger = logger
      @real_logger ||= self.default_logger(options[:name]) if !options[:null]
    end

    [ :info, :error ].each do |name|

      define_method(name) do |message|
        self.real_logger.send(name, message) if self.real_logger
      end

    end

    def self.null_logger
      self.new(nil, { :null => true })
    end

    protected

    def default_logger(name = "DatTCP")
      ::Logger.new(STDOUT).tap do |logger|
        logger.progname = "[#{name}]"
        logger.datetime_format = "%m/%d/%Y %H:%M:%S%p "
      end
    end

  end

end
