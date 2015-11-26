require 'assert'
require 'dat-tcp/worker'

require 'dat-worker-pool/worker'

module DatTCP::Worker

  class UnitTests < Assert::Context
    desc "DatTCP::Worker"
    setup do
      @worker_class = Class.new do
        include DatTCP::Worker
      end
    end
    subject{ @worker_class }

    should "be a dat-worker-pool worker" do
      assert_includes DatWorkerPool::Worker, subject
    end

  end

  class TestHelpersTests < UnitTests
    desc "TestHelpers"
    setup do
      @context_class = Class.new{ include TestHelpers }
    end
    subject{ @context_class }

    should "mixin dat-worker-pool's worker test helpers" do
      assert_includes DatWorkerPool::Worker::TestHelpers, @context_class
    end

  end

end
