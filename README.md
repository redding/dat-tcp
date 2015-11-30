# DatTCP

DatTCP is a generic threaded server implementation using Ruby's `TCPServer`. It is heavily influenced by `GServer` and [Puma](http://puma.io) and built using many of their patterns.

## Usage

```ruby
class Worker
  include DatTCP::Worker

  def work!(socket)
    message = socket.read
    socket.write(message)
  ensure
    socket.close
  end
end

server = DatTCP::Server.new(Worker)
```

Build your own server using `DatTCP::Server` and `DatTCP::Worker`. Define a worker class using the `Worker` mixin and pass it to the server. The server will call the worker's `work!` method for every new connection.

The server builds many workers which are each run in a separate thread. Each connection is handled by a single worker. The worker and its `work!` method should be threadsafe and expected to be called multiple times (don't use ivars or change global state).

### Starting

```ruby
server = DatTCP::Server.new(Worker, :num_workers => 1)
server.listen('localhost', 12000)
server.start
```

Create an instance of a server and optionally override any default settings. Call `listen` to build a `TCPServer` and bind to an address and port. Finally, call `start` to begin accepting and queueing connections to serve.

The `start` method returns the thread that is accepting connections.  Typically, you will want to `join` this thread so that it can perpetually accept connections:

```ruby
server.start.join
```

The server will then continue processing connections until it is signalled to stop or its process is killed.

### Stopping

Once the server has been started, it can be stopped using the `stop` method. Obviously, this can only be done in the current process if you didn't join the server thread:

```ruby
server.stop
```

If you plan to join the server thread, it's useful to setup signal traps so you can signal the server to stop:

```ruby
Signal.trap('TERM'){ server.stop }
server.start.join
```

```sh
# assume our process id is 12345
$ kill -TERM 12345
```

## Customization

### Configuration

* `backlog_size`     - The number of connections that can be pending. These
                       are connections that haven't been 'accepted' by the
                       server.
* `shutdown_timeout` - The number of seconds the server will wait for workers
                       to finish serving a connection. If they don't finish in
                       this time, the server will continue shutting down.
* `num_workers`      - The number of workers (threads) available to handle
                       connections.
* `logger`           - A logger to output debug messages to. All messages that
                       dat-tcp logs are debug level. For the best performance
                       don't pass a logger.
* `worker_params`    - Params that are passed to each worker instance. This
                       provides a way to pass custom data into a worker and
                       have it available for processing a client scoket. These
                       are available on every worker and typically shouldn't
                       be modified.

### Setting TCP server socket options

A DatTCP server allows configuring the TCP server socket it creates. This is done by passing a block to the `listen` method:

```ruby
server.listen('localhost', 12000) do |server_socket|
  server_socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
end
```

## Benchmarking

DatTCP comes with some scripts for benchmarking it's performance. These generate report text files that should be used to see if any additions or changes have altered it's previous performance. These can be run by doing the following:

```bash
bundle exec ruby bench/report.rb
```

This will both output the results to STDOUT and to a report file. It also generates a server report with some statistics on how long it spent processing.

### Notes

* The bench server is an echo server, it writes back whatever it was sent. Modifying the message sent, from what it currently is, will probably negatively impact performance and can no longer be compared with any historical reports.
* The calculations should be at a very minute scale (a single request should take around 1ms and probably less). This means it can vary from run to run. I recommend running it ~5 times and keeping the lowest results. In general, requests shouldn't take much longer than a 1ms on average.

## Installation

Add this line to your application's Gemfile:

    gem 'dat-tcp'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install dat-tcp

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

