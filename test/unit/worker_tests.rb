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

end
