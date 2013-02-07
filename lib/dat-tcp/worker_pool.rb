require 'thread'

require 'dat-tcp/logger'

module DatTCP

  class WorkerPool
    attr_reader :logger, :mutex, :cond, :spawned, :waiting

    def initialize(min = 0, max = 1, debug = false, &serve_proc)
      @min_workers = min
      @max_workers = max
      @logger      = DatTCP::Logger.new(debug)
      @serve_proc  = serve_proc

      @mutex = Mutex.new
      @cond  = ConditionVariable.new

      @queue   = []
      @spawned = 0
      @waiting = 0
      @workers = []

      @mutex.synchronize do
        @min_workers.times{ self.spawn_worker }
      end
    end

    # Adds the connection to it's queue and notifies any spawned workers (
    # `@cond.signal`). If there are no workers waiting then it will try to
    # spawn a worker, unless the maximum has been reached.
    def enqueue_connection(socket)
      return if !socket
      @mutex.synchronize do
        raise "Unable to add connection while shutting down" if @shutdown
        @queue << socket

        self.spawn_worker if self.no_workers_waiting? && !self.max_workers_spawned?
        @cond.signal
      end
    end

    # Flip the pool and workers shutdown flags and wake up any workers who are
    # waiting, so they can immediately shutdown. If a worker has picked up a
    # connection, then it will be joined and allowed to finish serving it.
    # **NOTE** Any connections that are on the queue are not served.
    def shutdown
      @mutex.synchronize do
        @shutdown = true
        @workers.each(&:shutdown)
        @cond.broadcast
      end

      # use this pattern instead of `each` -- we don't want to call `join` on
      # every worker (especially if they are shutting down on their own), we
      # just want to make sure that any who haven't had a chance to finish
      # get to (this is safe, otherwise you might get a dead thread in the
      # `each`).
      @workers.first.join until @workers.empty?

      @spawned = 0
      @workers = []
    end

    # Worker callbacks - workers call these to update the pool of their state

    def on_worker_waiting
      @waiting += 1
    end

    def on_worker_stop_waiting
      @waiting -= 1
    end

    def on_worker_shutdown(worker)
      @spawned -= 1
      @workers.delete worker
    end

    protected

    def spawn_worker
      worker = DatTCP::Worker.new(self, @queue) do |socket, worker|
        self.serve_socket(socket, worker)
      end
      @workers << worker
      @spawned += 1
      worker
    end

    def serve_socket(socket, worker)
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

    def no_workers_waiting?
      @waiting <= 0
    end

    def max_workers_spawned?
      @max_workers <= @spawned
    end

  end

  class Worker

    def initialize(pool, queue, &block)
      @pool  = pool
      @queue = queue
      @mutex = @pool.mutex
      @cond  = @pool.cond
      @block = block

      @shutdown = false
      @thread = Thread.new{ work_loop }
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
        @block.call(@queue.pop, self)
      end
    ensure
      @pool.on_worker_shutdown(self)
    end

    # Wait for a connection to serve by checking if the queue is empty. If so
    # enter a "waiting" state (`@cond.wait(@mutex)`). The pool will signal to
    # wake up workers and they can check the queue again. The `@mutex` ensures
    # only one thread gets to check the queue at a time.
    def wait_for_work
      @mutex.synchronize do
        while @queue.empty?
          return if @shutdown

          @pool.on_worker_waiting
          @cond.wait(@mutex)
          @pool.on_worker_stop_waiting
        end
      end
    end

  end

end
