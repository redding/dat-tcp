require 'assert'
require 'dat-tcp/server_spy'

class DatTCP::ServerSpy

  class UnitTests < Assert::Context
    desc "DatTCP::ServerSpy"
    setup do
      @server_spy = DatTCP::ServerSpy.new
    end
    subject{ @server_spy }

    should have_readers :ip, :port, :file_descriptor
    should have_readers :client_file_descriptors
    should have_readers :worker_start_procs, :worker_shutdown_procs
    should have_readers :worker_sleep_procs, :worker_wakeup_procs
    should have_readers :waiting_for_pause
    should have_readers :waiting_for_stop, :waiting_for_halt
    should have_readers :listen_called, :start_called
    should have_readers :stop_listen_called, :pause_called
    should have_readers :stop_called, :halt_called
    should have_accessors :serve_proc
    should have_imeths :listening?, :running?
    should have_imeths :listen, :stop_listen
    should have_imeths :start, :stop, :halt
    should have_imeths :on_worker_start, :on_worker_shutdown
    should have_imeths :on_worker_sleep, :on_worker_wakeup

    should "default its attributes" do
      assert_nil subject.ip
      assert_nil subject.port
      assert_nil subject.file_descriptor
      assert_equal [], subject.client_file_descriptors

      assert_equal [], subject.worker_start_procs
      assert_equal [], subject.worker_shutdown_procs
      assert_equal [], subject.worker_sleep_procs
      assert_equal [], subject.worker_wakeup_procs

      assert_nil subject.waiting_for_pause
      assert_nil subject.waiting_for_stop
      assert_nil subject.waiting_for_halt

      assert_false subject.listen_called
      assert_false subject.stop_listen_called
      assert_false subject.start_called
      assert_false subject.pause_called
      assert_false subject.stop_called
      assert_false subject.halt_called

      assert_instance_of Proc, subject.serve_proc
    end

    should "know if its listening or not" do
      assert_false subject.listening?
      subject.listen(Factory.integer)
      assert_true subject.listening?
      subject.stop_listen
      assert_false subject.listening?
    end

    should "know if its running or not" do
      assert_false subject.running?
      subject.start
      assert_true subject.running?

      subject.pause
      assert_false subject.running?
      subject.pause_called = false

      subject.stop
      assert_false subject.running?
      subject.stop_called = false

      subject.halt
      assert_false subject.running?
    end

    should "set its ip, port and listen flag using `listen`" do
      ip = Factory.string
      port = Factory.integer

      assert_false subject.listen_called
      subject.listen(ip, port)
      assert_equal ip, subject.ip
      assert_equal port, subject.port
      assert_true subject.listen_called
    end

    should "set its file descriptor and listen flag using `listen`" do
      fd = Factory.integer

      assert_false subject.listen_called
      subject.listen(fd)
      assert_equal fd, subject.file_descriptor
      assert_true subject.listen_called
    end

    should "set its stop listen flag using `stop_listen`" do
      assert_false subject.stop_listen_called
      subject.stop_listen
      assert_true subject.stop_listen_called
    end

    should "set its client file descriptors and its start flag using `start`" do
      client_fds = [ Factory.integer, Factory.integer ]

      assert_false subject.start_called
      subject.start(client_fds)
      assert_equal client_fds, subject.client_file_descriptors
      assert_true subject.start_called
    end

    should "set its waiting for pause and pause called flag using `pause`" do
      wait = Factory.boolean

      assert_false subject.pause_called
      subject.pause(wait)
      assert_equal wait, subject.waiting_for_pause
      assert_true subject.pause_called
    end

    should "set its waiting for stop and stop called flag using `stop`" do
      wait = Factory.boolean

      assert_false subject.stop_called
      subject.stop(wait)
      assert_equal wait, subject.waiting_for_stop
      assert_true subject.stop_called
    end

    should "set its waiting for halt and halt called flag using `halt`" do
      wait = Factory.boolean

      assert_false subject.halt_called
      subject.halt(wait)
      assert_equal wait, subject.waiting_for_halt
      assert_true subject.halt_called
    end

    should "allow reading/writing its worker procs" do
      proc = Proc.new{}

      subject.on_worker_start(&proc)
      assert_equal [proc], subject.worker_start_procs

      subject.on_worker_shutdown(&proc)
      assert_equal [proc], subject.worker_shutdown_procs

      subject.on_worker_sleep(&proc)
      assert_equal [proc], subject.worker_sleep_procs

      subject.on_worker_wakeup(&proc)
      assert_equal [proc], subject.worker_wakeup_procs
    end

  end

end
