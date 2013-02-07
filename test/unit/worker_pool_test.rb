require 'assert'

class DatTCP::WorkerPool

  class BaseTest < Assert::Context
    desc "DatTCP::WorkerPool"
    setup do
      @work_pool = DatTCP::WorkerPool.new{ }
    end
    subject{ @work_pool }

    should have_instance_methods :logger, :mutex, :cond, :spawned, :waiting
    should have_instance_methods :enqueue_connection, :shutdown
    should have_instance_methods :on_worker_waiting, :on_worker_stop_waiting, :on_worker_shutdown

  end

  class WithMiniumWorkersTest < BaseTest
    desc "DatTCP::WorkerPool"
    setup do
      @work_pool = DatTCP::WorkerPool.new(2)
    end

    should "have spun up the minimum number of workers" do
      assert_equal 2, @work_pool.spawned
      assert_equal 2, @work_pool.waiting
    end

  end

  class EnqueueAndWorkTest < BaseTest
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

  class WorkerBehaviorTest < BaseTest
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

  class ShutdownTest < BaseTest
    desc "shutdown"
    setup do
      @mutex = Mutex.new
      @finished = []
      @work_pool = DatTCP::WorkerPool.new(1, 2) do |socket|
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

      @work_pool.shutdown

      # NOTE, the last connection shouldn't have been run, as it wasn't
      # picked up by a worker
      assert_includes     'a', @finished
      assert_includes     'b', @finished
      assert_not_includes 'c', @finished

      assert_equal 0, @work_pool.spawned
      assert_equal 0, @work_pool.waiting
    end

  end

end
