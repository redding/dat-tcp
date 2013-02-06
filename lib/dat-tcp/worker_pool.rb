require 'thread'

require 'dat-tcp/logger'

module DatTCP

  class WorkerPool
    attr_reader :max, :list, :logger

    def initialize(max = 1, logger = nil, &serve_client_proc)
      @max    = max
      @logger = logger || DatTCP::Logger::Null.new
      @serve_client_proc = serve_client_proc

      @list = []

      @mutex = Mutex.new
      @condition_variable = ConditionVariable.new
    end

    # This uses the mutex and condition variable to sleep the current thread
    # until signaled. When a thread closes down, it signals, causing this thread
    # to wakeup. This will run the loop again, and as long as a worker is
    # available, the method will return. Otherwise it will sleep again waiting
    # to be signaled.
    def wait_for_available
      @mutex.synchronize do
        while self.list.size >= self.max
          @condition_variable.wait(@mutex)
        end
      end
    end

    def process(connecting_socket)
      return if !connecting_socket
      self.wait_for_available
      worker_id = self.list.size + 1
      @list << Thread.new{ self.serve_client(worker_id, connecting_socket) }
    end

    # Finish simply sleeps the current thread until signaled. Again, when a
    # worker thread closes down, it signals. This will cause this to wake up and
    # continue running the loop. Once the list is empty, the method will return.
    # Otherwise this will sleep until signaled again. This is a graceful
    # shutdown, letting the threads finish their processing.
    def finish
      @mutex.synchronize do
        @list.reject!{|thread| !thread.alive? }
        while !self.list.empty?
          @condition_variable.wait(@mutex)
        end
      end
    end

    protected

    def log(message, worker_id)
      self.logger.info("[Worker##{worker_id}] #{message}") if self.logger
    end

    def serve_client(worker_id, connecting_socket)
      begin
        Thread.current["client_address"] = connecting_socket.peeraddr[1, 2].reverse.join(':')
        self.log("Connecting #{Thread.current["client_address"]}", worker_id)
        @serve_client_proc.call(connecting_socket)
      rescue Exception => exception
        self.log("Exception occurred, stopping worker", worker_id)
      ensure
        self.disconnect_client(worker_id, connecting_socket, exception)
      end
    end

    # Closes the client connection and also shuts the thread down. This is done
    # by removing the thread from the list. This is wrapped in a mutex
    # synchronize, to ensure only one thread interacts with list at a time. Also
    # the condition variable is signaled to trigger the `finish` or
    # `wait_for_available` methods.
    def disconnect_client(worker_id, connecting_socket, exception)
      connecting_socket.close rescue false
      @mutex.synchronize do
        @list.delete(Thread.current)
        @condition_variable.signal
      end
      if exception
        self.log("#{exception.class}: #{exception.message}", worker_id)
        self.log(exception.backtrace.join("\n"), worker_id)
      end
      self.log("Disconnecting #{Thread.current["client_address"]}", worker_id)
    end

  end

end
