require 'assert'

require 'benchmark'

class DatTCP::Workers

  class BaseTest < Assert::Context
    desc "DatTCP::Workers"
    setup do
      @workers = DatTCP::Workers.new(1)
    end
    subject{ @workers }

    should have_instance_methods :max, :list, :logger, :wait_for_available, :process, :finish
  end

  class WaitForAvailableTest < BaseTest
    desc "wait_for_available"
    setup do
      @sleep_time = sleep_time = 0.01
      @workers.process(FakeSocket.new){|client| sleep(sleep_time) }
      @benchmark = Benchmark.measure{ @workers.wait_for_available }
    end

    should "have waited for an available worker" do
      what_failed = "Expected real time of #{@benchmark.real}ms to be greater than #{@sleep_time}ms"
      assert @benchmark.real > @sleep_time, nil, what_failed
    end
  end

  class ProcessTest < BaseTest
    desc "process"
    setup do
      @client = FakeSocket.new
      @workers.process(@client){|client| client.write('poop') }
    end

    should "add a thread to the workers list" do
      assert_equal 1, @workers.list.size
    end
    should "run the block passed to it" do
      @workers.list.first.join # make sure the worker thread runs

      assert_includes 'poop', @client.written_values
    end
  end

  class FinishTest < BaseTest
    desc "finish"
    setup do
      @sleep_time = sleep_time = 0.01
      @workers.process(FakeSocket.new){|client| sleep(sleep_time) }
      @benchmark = Benchmark.measure{ @workers.finish }
    end

    should "have waited for the workers threads to finish processing" do
      what_failed = "Expected real time of #{@benchmark.real}ms to be greater than #{@sleep_time}ms"
      assert @benchmark.real > @sleep_time, nil, what_failed
    end
  end

end
