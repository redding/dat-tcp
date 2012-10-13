# Threaded Server

Threaded Server is a wrapper to ruby's `TCPServer` that runs separate threads to handle connections. It is heavily influenced by ruby's `GServer` and built using it's patterns.

## Usage

To define your own server, inherit from `ThreadedServer` and define the `serve` method. Then, when your server receives a new connection, it will hand the socket to your `serve` method and it can be read from and written to:

```ruby
class MyServer < ThreadedServer

  def serve(socket)
    # read from socket
    # write to socket
  end

end
```

An important thing to note is that, when there's a new connection and the `serve` method is called, it's done in a separate thread. This means that your `serve` method should be written using threadsafe patterns.

### Starting

To start the server, create a new instance passing a host and port. Then call the `start` method:

```ruby
server = MyServer.new('localhost', 8000)
server.start
```

This will start running the server in a separate thread, allowing your current thread to continue procesing. The server starts an infinite loop checking for new connections and spawning workers to handle them. Because of the separate thread, this won't stop your current ruby process from executing. Many times, it's desirable to go ahead and suspend processing of your current thread and to allow the server thread to take over. This can be done using the `join_thread` method:

```ruby
server.join_thread
```

Once this is done, the server thread will take over, which will put the process into the infinite server loop. At this point it can only be stopped using signals (see "Usage - Stopping" for how this can be done).

**NOTE** See "Advanced - Server Thread" for more information and reasnoning behind running the server loop in a separate thread.

### Processing Connections

`ThreadedServer` provides a wrapper to the connecting TCP socket. It passes this to the `serve` method. It provides some helpers for reading and writing to the client, but in general proxies most of it's methods to the actual ruby `TCPSocket`. The 2 primary methods it provides are `read` and `write`:

```ruby
# a possible `serve` method
def serve(client)
  # read the size of the message, expected in the first 4 bytes
  serialized_size = client.read(4)
  size = serialized_size.unpack('N').first
  message = client.read(size)
  # do some processing to generate a response
  response_size = response_message.bytesize
  serialized_size = [ response_size ].pack('N')
  client.write(serialized_size + response_message)
end
```

The `read` and `write` methods provide a clean interface for interacting with the client. In the case you want, you can always access the `TCPSocket` directly using the `socket` method:

```ruby
def serve(client)
  # get the socket directly
  socket = client.socket
  # handle the connection using `socket`
end
```

### Stopping

Once the server has been started, it can be stopped using the `stop` method. Obviously, this can only be done in the current process if you didn't join the server thread:

```ruby
server.stop
```

If you are joining the server thread, it's useful to setup signal traps before joining the server thread:

```ruby
server = MyServer.new('localhost', 8000)
server.start
Signal.trap('QUIT'){ server.stop }
server.join_thread
```

Then you can use the `kill` command to stop the server. Something like:

```
# assume our process id is 12345
# unix
kill -15 12345
# or in ruby
# Process.kill('QUIT', 12345)
```

### Customization

As previously mentioned, when creating your own server, you should define a custom `serve` method. In addition to this, there are a number of ways to customize the server you are running.

#### Max Workers

When creating an instance of a server, servers can optionally be passed a number of workers to use:

```ruby
server = MyServer.new('localhost', 8000, { :max_workers => 10 })
```

Then, when the server is started, it will spin up to 10 worker threads for processing connections.

#### Logging

`ThreadedServer` has logging built in for when it starts or stops, when a client connects or disconnects and when an error occurs. To provide custom logging, a logger can be passed when creating the server:

```ruby
server = MyServer.new('localhost', 8000, { :logger => my_logger })
```

If a logger is not specified, by default, `ThreadedServer` will log to stdout. If you wish to turn logging off, this can be done by setting `logging` to false:

```ruby
server = MyServer.new('localhost', 8000, { :logging => false })
```

## Advanced

### Server Thread

**TODO** Make sure that the server in a separate thread will actually work with testing, otherwise don't say that (should work)

`ThreadedServer` uses a separate thread to run the TCP server in. This allows for better control over the server and is also convenient for running tests against the server. Also, the server thread can also be joined into the current thread, which is essentially the same as not running the server in a thread.

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

The server keeps track of the thread so that it can check the thread's status and join the thread.
