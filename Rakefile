require "bundler/gem_tasks"

namespace :bench do

  desc "Send test requests to the Benchmark server"
  task :test, [ :number ] do |t, args|
    require 'bench/client'
    Bench.run_client('127.0.0.1', 12000, args[:number])
  end

  desc "Start the Benchmark server"
  task :start_server do
    require 'bench/server'
    Bench.start_server('127.0.0.1', 12000)
  end

  desc "Stop the Benchmark server"
  task :stop_server do
    require 'bench/server'
    Bench.stop_server
  end

end
