require 'thread'

require 'dat-tcp/logger'

module DatTCP

  class WorkerPool
    attr_reader :logger, :spawned

    def initialize(min = 0, max = 1, debug = false, &serve_proc)
      @min_workers = min
      @max_workers = max
      @logger      = DatTCP::Logger.new(debug)
      @serve_proc  = serve_proc

      @queue           = DatTCP::Queue.new
      @workers_waiting = DatTCP::WorkersWaiting.new

      @mutex   = Mutex.new
      @workers = []
      @spawned = 0

      @min_workers.times{ self.spawn_worker }
    end

    def waiting
      @workers_waiting.count
    end

    # Check if all workers are busy before adding the connection. When the
    # connection is added, a worker will stop waiting (if it was idle). Because
    # of that, we can't reliably check if all workers are busy. We might think
    # all workers are busy because we just woke up a sleeping worker to serve
    # this connection. Then we would spawn a worker to do nothing.
    def enqueue_connection(socket)
      return if !socket
      new_worker_needed = all_workers_are_busy?
      @queue.push socket
      self.spawn_worker if new_worker_needed && havent_reached_max_workers?
    end

    # Shutdown each worker and then the queue. Shutting down the queue will
    # signal any workers waiting on it to wake up, so they can start shutting
    # down. If a worker is processing a connection, then it will be joined and
    # allowed to finish.
    # **NOTE** Any connections that are on the queue are not served.
    def shutdown
      @workers.each(&:shutdown)
      @queue.shutdown

      # use this pattern instead of `each` -- we don't want to call `join` on
      # every worker (especially if they are shutting down on their own), we
      # just want to make sure that any who haven't had a chance to finish
      # get to (this is safe, otherwise you might get a dead thread in the
      # `each`).
      @workers.first.join until @workers.empty?
    end

    # public, because workers need to call it for themselves
    def despawn_worker(worker)
      @mutex.synchronize do
        @spawned -= 1
        @workers.delete worker
      end
    end

    protected

    def spawn_worker
      @mutex.synchronize do
        worker = DatTCP::Worker.new(self, @queue, @workers_waiting) do |socket|
          self.serve_socket(socket)
        end
        @workers << worker
        @spawned += 1
        worker
      end
    end

    def serve_socket(socket)
      begin
        @serve_proc.call(socket)
      rescue Exception => exception
        self.logger.error "Exception raised while serving connection!"
        self.logger.error "#{exception.class}: #{exception.message}"
        self.logger.error exception.backtrace.join("\n")
      ensure
        socket.close rescue false
      end
    end

    def all_workers_are_busy?
      @workers_waiting.count <= 0
    end

    def havent_reached_max_workers?
      @mutex.synchronize do
        @spawned < @max_workers
      end
    end

  end

  class Queue

    def initialize
      @todo = []
      @shutdown = false
      @mutex              = Mutex.new
      @condition_variable = ConditionVariable.new
    end

    # Add the connection and wake up the first worker (the `signal`) that's
    # waiting (because of `wait_for_new_connection`)
    def push(socket)
      raise "Unable to add connection while shutting down" if @shutdown
      @mutex.synchronize do
        @todo << socket
        @condition_variable.signal
      end
    end

    def pop
      @mutex.synchronize{ @todo.pop }
    end

    def empty?
      @mutex.synchronize{ @todo.empty? }
    end

    # wait to be signaled by `push`
    def wait_for_new_connection
      @mutex.synchronize{ @condition_variable.wait(@mutex) }
    end

    # wake up any workers who are idle (because of `wait_for_new_connection`)
    def shutdown
      @shutdown = true
      @mutex.synchronize{ @condition_variable.broadcast }
    end

  end

  class Worker

    def initialize(pool, queue, workers_waiting, &block)
      @pool            = pool
      @queue           = queue
      @workers_waiting = workers_waiting
      @block           = block
      @shutdown        = false
      @thread          = Thread.new{ work_loop }
    end

    def shutdown
      @shutdown = true
    end

    def join
      @thread.join if @thread
    end

    protected

    def work_loop
      loop do
        self.wait_for_work
        break if @shutdown
        @block.call @queue.pop
      end
    ensure
      @pool.despawn_worker(self)
    end

    # Wait for a connection to serve by checking if the queue is empty.
    def wait_for_work
      while @queue.empty?
        return if @shutdown
        @workers_waiting.increment
        @queue.wait_for_new_connection
        @workers_waiting.decrement
      end
    end

  end

  class WorkersWaiting
    attr_reader :count

    def initialize
      @mutex = Mutex.new
      @count = 0
    end

    def increment
      @mutex.synchronize{ @count += 1 }
    end

    def decrement
      @mutex.synchronize{ @count -= 1 }
    end

  end

end
