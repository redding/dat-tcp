class FakeSocket

  def initialize(*bytes)
    @out = StringIO.new
    @in  = StringIO.new
    reset(*bytes)
  end

  def reset(*new_bytes)
    @in << new_bytes.join; @in.rewind;
  end

  def in;  @in.string;  end
  def out; @out.string; end

  # Socket methods -- requied by Sanford::Protocol

  def read
    @in.read
  end

  def write(bytes)
    @out << bytes
  end

  def close
    @closed = true
  end

end
