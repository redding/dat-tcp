require 'assert'
require 'test/support/fake_socket'
require 'dat-tcp/worker_pool'

class DatTCP::WorkerPool

  class BaseTests < Assert::Context
    desc "DatTCP::WorkerPool"
    setup do
      @work_pool = DatTCP::WorkerPool.new{ }
    end
    subject{ @work_pool }

    should have_instance_methods :logger, :enqueue_connection, :shutdown
    should have_instance_methods :despawn_worker, :spawned, :waiting

  end

  class WithMiniumWorkersTests < BaseTests
    desc "DatTCP::WorkerPool"
    setup do
      @work_pool = DatTCP::WorkerPool.new(2)
    end

    should "have spun up the minimum number of workers" do
      assert_equal 2, @work_pool.spawned
      assert_equal 2, @work_pool.waiting
    end

  end

  class EnqueueAndWorkTests < BaseTests
    desc "enqueue_connection and serve"

    should "have added the connection and served it by calling the passed block" do
      serve_result = nil
      work_pool = DatTCP::WorkerPool.new(1){|socket| serve_result = socket.read }
      work_pool.enqueue_connection FakeSocket.new 'test'

      assert_equal 'test', serve_result
    end

    should "swallow serve exceptions, so workers don't end unexpectedly" do
      work_pool = DatTCP::WorkerPool.new(1){|socket| raise 'test' }
      work_pool.enqueue_connection FakeSocket.new
      worker = work_pool.instance_variable_get("@workers").first

      assert_equal 1, work_pool.spawned
      assert_equal 1, work_pool.waiting

      assert worker.instance_variable_get("@thread").alive?
    end
  end

  class WorkerBehaviorTests < BaseTests
    desc "workers"
    setup do
      @work_pool = DatTCP::WorkerPool.new(1, 2){|socket| sleep(socket.read.to_i) }
    end

    should "be created as needed and only go up to the maximum number allowed" do
      # the minimum should be spawned and waiting
      assert_equal 1, @work_pool.spawned
      assert_equal 1, @work_pool.waiting

      # the minimum should be spawned, but no longer waiting
      @work_pool.enqueue_connection FakeSocket.new 5
      assert_equal 1, @work_pool.spawned
      assert_equal 0, @work_pool.waiting

      # an additional worker should be spawned
      @work_pool.enqueue_connection FakeSocket.new 5
      assert_equal 2, @work_pool.spawned
      assert_equal 0, @work_pool.waiting

      # no additional workers are spawned, the connection waits to be processed
      @work_pool.enqueue_connection FakeSocket.new 5
      assert_equal 2, @work_pool.spawned
      assert_equal 0, @work_pool.waiting
    end

    should "go back to waiting when they finish working" do
      assert_equal 1, @work_pool.spawned
      assert_equal 1, @work_pool.waiting

      @work_pool.enqueue_connection FakeSocket.new 1
      assert_equal 1, @work_pool.spawned
      assert_equal 0, @work_pool.waiting

      sleep 1 # allow the worker to run

      assert_equal 1, @work_pool.spawned
      assert_equal 1, @work_pool.waiting
    end

  end

  class ShutdownTests < BaseTests
    desc "shutdown"
    setup do
      @mutex = Mutex.new
      @finished = []
      @work_pool = DatTCP::WorkerPool.new(1, 2, true) do |socket|
        sleep 1
        @mutex.synchronize{ @finished << socket.read }
      end
      @work_pool.enqueue_connection FakeSocket.new 'a'
      @work_pool.enqueue_connection FakeSocket.new 'b'
      @work_pool.enqueue_connection FakeSocket.new 'c'
    end

    should "allow any connections that have been picked up to run" do
      # make sure the workers haven't served the connections
      assert_equal [], @finished

      @work_pool.shutdown(5)

      # NOTE, the last connection shouldn't have been run, as it wasn't
      # picked up by a worker
      assert_includes     'a', @finished
      assert_includes     'b', @finished
      assert_not_includes 'c', @finished

      assert_equal 0, @work_pool.spawned
      assert_equal 0, @work_pool.waiting
    end

    should "timeout if the workers take to long to finish" do
       # make sure the workers haven't served the connections
      assert_equal [], @finished

      assert_raises(DatTCP::TimeoutError) do
        @work_pool.shutdown(0.1)
      end
    end

  end

end
