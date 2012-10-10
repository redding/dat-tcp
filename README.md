# Threaded Server

Threaded Server is a wrapper to ruby's `TCPServer`. It is heavily influenced by ruby's `GServer`.

## Usage

To define your own server, inherit from `ThreadedServer` and define the `serve` method. When your server receives a new connection, it will hand the socket to your `serve` method:

**TODO** Don't love `serve`, might use a different method than what GServer used.

```ruby
class MyServer < ThreadedServer

  def serve(socket)
    # read from the socket
    # write to the socket
  end

end
```

It's important to note that each request is run in a separate thread. Be mindful when modifying global resources and writing your code in general.

### Starting

To start the server, after creating a new instance of it, you can call the `start` method:

```ruby
server = MyServer.new('localhost', 8000)
server.start
```

This will start running the server and it will begin accepting connections and processing them. This runs the server in it's own thread (see Advanced section). If you want to just run the server in this ruby process, you can join it's thread into your current one:

**TODO** Don't like using `join`, it's what we call on the thread, but it sounds weird saying `server.join`.

```ruby
server.join
```

Once this is done, the server thread will take over, which will put the process into the infinite server loop. At this point it can only be stopped using signals.

### Stopping

To stop the server, you can use the `stop` method:

```ruby
server.stop
```

This works as long as you haven't joined the server's thread into the current one. Otherwise, a signal trap should be used:

**TODO** Verify the signal stuff works as expected

```ruby
Signal.trap('TERM'){ server.stop }
```

`stop` shuts the server down by stopping the server loop, closing the TCP connection and then waiting on all the worker threads to finish.

### Configuration

**TODO**

* max workers
* logger/logging

## Advanced

### Server Thread

The server uses a separate thread to run the TCP server loop. The primary reason for doing this, is it allows a single ruby process to keep working while the server runs in it's own thread. This is very convenient for testing (**TODO** should be, not sure about this yet). Also, you can always join the server's thread into your current thread, which is basically the same as not running the server in a thread.

To manage this, whenever the server is started, it creates a new thread and starts the TCP server loop in it:

```ruby
def start
  @thread = Thread.new do
    tcp_server = TCPServer.new(host, port)
    while !@shutdown
      socket = tcp_server.accept
      # handle socket
    end
  end
end
```

A reference to the thread is stored off, this way, the current process can check the status of the thread and can also easily join the thread into the current one.

### Connection Timeout Stuff

**TODO**
