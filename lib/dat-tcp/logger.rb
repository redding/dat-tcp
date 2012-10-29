# DatTCP's logger module acts as a generator for either a debug or null logger.
# This allows the server and workers to always assume they have some logger
# object and not have to worry about conditionally checking if a logger is
# present. The null logger takes all messages and does nothing with them. When
# debug mode is turned off, this logger is used, which keeps the server from
# logging. The debug logger uses an instance of ruby's standard logger and
# writes to STDOUT.
#
require 'logger'

module DatTCP::Logger

  def self.new(debug)
     !!debug ? DatTCP::Logger::Debug.new : DatTCP::Logger::Null.new
  end

  module Debug

    def self.new
      ::Logger.new(STDOUT).tap do |logger|
        logger.progname = "[#{self.name}]"
        logger.datetime_format = "%m/%d/%Y %H:%M:%S%p "
      end
    end

  end

  class Null

    Logger::Severity.constants.each do |name|
      define_method(name.downcase){|*args| } # no-op
    end

  end

end
