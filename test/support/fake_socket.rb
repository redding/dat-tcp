class FakeSocket
  attr_reader :written_values

  def initialize
    @written_values = []
  end

  def peeraddr
    [ nil, 12345, "fakehost", nil ]
  end

  def print(value)
    @written_values << value
  end

  def close
    true
  end

end
