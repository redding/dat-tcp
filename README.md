# DatTCP

DatTCP is a generic server implementation that uses ruby's `TCPServer` and threads. It is heavily influenced by ruby's `GServer` and built using it's patterns.

## Usage

To define your own server, mixin `DatTCP::Server` and define the `serve` method. Then, when your server receives a new connection, it will hand the socket to your `serve` method and it can be read from and written to:

```ruby
class MyServer
  include DatTCP::Server

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

**NOTE** See "Advanced - Server Thread" for more information and reasoning behind running the server loop in a separate thread.

### Processing Connections

DatTCP provides a wrapper to the connecting TCP socket and passes it to the `serve` method. It provides some helpers for reading and writing to the client, but in general proxies most of it's methods to the actual ruby `TCPSocket`. The 2 primary methods it provides are `read` and `write`:

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

Then you can use the UNIX `kill` command to stop the server. Something like:

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

Then, when the server is started, it will allow up to 10 worker threads for processing connections.

#### Debug

DatTCP has a debug mode built in. When turned on, it logs when it starts or stops, when a client connects or disconnects and when an error occurs. It's off by default, to turn it on, set `debug` to `true`:

```ruby
server = MyServer.new('localhost', 8000, { :debug => true })
```

When turned on, DatTCP will log it's debug messages to STDOUT.

#### Connection Ready Timeout

DatTCP uses `IO.select` combined with `accept_nonblock` on the TCP server to listen for new connections (see "Advanced - Listening For Connections" section for more details and reasoning). `IO.select` takes a timeout which can be customized by passing `ready_timeout` when creating a new server. This throttles how spastic the server is when waiting for a new connection, but also limits how responsive the server is when told to stop:

```ruby
server = MyServer.new('localhost', 8000, { :ready_timeout => 0 }) # or, no timeout
```

Again, see the "Advanced - Listening For Connections" for a more in-depth explanation.

## Benchmarking

DatTCP comes with some rake tasks for benchmarking it's performance. These generate report text files that should be used to see if any additions or changes have altered it's previous performance. These can be run by doing the following:

In a shell, start the server:

```bash
bundle exec rake bench:server
```

This will start the server which will begin listening for requests. The report can then be generated by running this rake task in another shell:

```bash
bundle exec rake bench:report
```

This will both output the results to STDOUT and to a report file. When the server is stopped, it will also write out some statistics on how long it spent processing.

### Notes

* The bench server is an echo server, it writes back whatever it was sent. Modifying the message sent, from what it currently is, will probably negatively impact performance and can no longer be compared with any historical reports.
* The calculations should be at a very minute scale (a single request should take around 1ms and probably less). This means it can vary from run to run. I recommend running it ~5 times and keeping the lowest results. In general, requests shouldn't take much longer than a 1ms on average.

## Advanced

### Server Thread

DatTCP uses a separate thread to run the TCP server in. This allows for better control over the server and is also convenient for running tests against the server. Also, the server thread can also be joined into the current thread, which is essentially the same as not running the server in a thread.

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

### Listening For Connections

DatTCP listens for connections by using a combination of `IO.select` and socket's `accept`. When the server is started, it creates a TCP socket instance and calls `IO.select` with a timeout. This will return if a client connects or after the timeout has expired. If a client connected, the server will then call `accept` on the TCP socket. At this point, the accept-loop is broken out of and the client socket from `accept` is returned. In the case there isn't a connection after the `IO.select` timeout, the loop starts over. Also during this loop, the server checks to see if it's been stopped. If so, the loop is also broken out of. The code for this looks something like:

```ruby
loop do
  if IO.select([ server_socket ], nil nil, timeout)
    return server_socket.accept
  elsif shutdown?
    return
  end
end
```

DatTCP uses `IO.select` because the `accept` call blocks, which causes the process to become unresponsive, in the case you want to stop or restart it. Using `IO.select` before calling `accept` allows the server to be responsive because it only waits for a known timeout.
