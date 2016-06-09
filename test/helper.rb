# this file is automatically required when you run `assert`
# put any test helpers here

# add the root dir to the load path
$LOAD_PATH.unshift(File.expand_path("../..", __FILE__))

# require pry for debugging (`binding.pry`)
require 'pry'

require 'pathname'
ROOT_PATH = Pathname.new(File.expand_path('../..', __FILE__))

require 'logger'
TEST_LOGGER = if ENV['DEBUG']
  # don't show datetime in the logs
  Logger.new(ROOT_PATH.join("log/test.log")).tap{ |l| l.datetime_format = '' }
end

JOIN_SECONDS = 0.1

require 'test/support/factory'

# 1.8.7 backfills

# Array#sample
if !(a = Array.new).respond_to?(:sample) && a.respond_to?(:choice)
  class Array
    alias_method :sample, :choice
  end
end
