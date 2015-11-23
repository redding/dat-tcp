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

require 'test/support/factory'
