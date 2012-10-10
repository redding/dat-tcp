class ThreadedServer

  class Workers
    attr_reader :server, :max, :list, :logger

    def initialize(server, max, logger)
      @server = server
      @max = max
      @list = []
      @logger = logger

      @mutex = Mutex.new
      @resource = ConditionVariable.new
    end

    def wait_for_available
      @mutex.synchronize do
        while self.list.size >= self.max
          @resource.wait(@mutex)
        end
      end
    end

    def handle(client)
      worker_id = self.list.size + 1
      @list << Thread.new do
        self.serve_client(worker_id, client)
      end
    end

    def stop
      self.list.each{|thread| thread.join }
    end

    protected

    def log(message, worker_id, peeraddr)
      host, port = [ peeraddr[2], peeraddr[1] ]
      self.logger.info("[Worker##{worker_id}|#{host}:#{port}] #{message}")
    end

    def serve_client(worker_id, client)
      begin
        peeraddr = client.peeraddr
        self.log("Connecting", worker_id, peeraddr)
        self.server.serve(client)
      rescue Exception => exception
        self.log("Exception occurred, stopping worker", worker_id, peeraddr)
      ensure
        client.close rescue false
        @mutex.synchronize do
          @list.delete(Thread.current)
          @resource.signal
        end
        self.log("Disconnecting", worker_id, peeraddr)
      end
    end

  end

end
