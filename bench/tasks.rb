namespace :bench do

  task :load do
    require 'bench/runner'
  end

  desc "Start the Benchmark echo server"
  task :server => :load do
    Bench::ServerRunner.new.run_server
  end

  desc "Run a Benchmark report against the Benchmark server"
  task :report => :load do
    Bench::ClientRunner.new.build_report
  end

  desc "Run X requests against the Benchmark server"
  task :echo, [ :times, :message ] => :load do |t, args|
    runner = Bench::ClientRunner.new(:output => '/dev/null')
    runner.make_requests(args[:message], args[:times] || 1, true)
  end

end
