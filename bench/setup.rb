require 'dat-tcp'
require 'pathname'

ROOT_PATH = Pathname.new(File.expand_path('../..', __FILE__))

IP_AND_PORT  = ['127.0.0.1', 12000]
NUM_WORKERS  = 4

TIME_MODIFIER = 10 ** 4 # 4 decimal places

LOGGER = if ENV['DEBUG']
  Logger.new(ROOT_PATH.join("log/bench.log")).tap do |l|
    l.datetime_format = '' # don't show datetime in the logs
  end
end

module BenchRunner

  private

  def output(message, puts = true)
    method = puts ? :puts : :print
    self.send(method, message)
    @output_file.send(method, message)
    STDOUT.flush if method == :print
  end

  def round_and_display(time_in_ms)
    display_time(round_time(time_in_ms))
  end

  def round_time(time_in_ms)
    (time_in_ms * TIME_MODIFIER).to_i / TIME_MODIFIER.to_f
  end

  def display_time(time)
    integer, fractional = time.to_s.split('.')
    [integer, fractional.ljust(4, '0')].join('.')
  end

end
