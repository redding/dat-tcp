class SpyLogger
  attr_reader :info_messages, :error_messages

  def info(message)
    @info_messages ||= []
    @info_messages << message
  end

  def error(message)
    @error_messages ||= []
    @error_messages << message
  end

end
