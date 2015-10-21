module ARKWEB

class ClosedHash < Hash
  alias open_get []

  def [](k)
    self.get(k)
  end

  def get(k, iname: 'item', kname: 'key')
    if self.has_key?(k)
      return self.open_get(k)
    else
      raise ArgumentError, "#{self.inspect} has no #{iname} by #{kname}: #{k.inspect}"
    end
  end

  def inspect
    "#<AW::ClosedHash:#{self}>"
  end
end

end

