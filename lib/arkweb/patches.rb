
class Pathname
  def glob(str)
    Dir[self + str].map {|p| Pathname.new(p) }
  end

  def first(str)
    self.glob(str).first
  end
end

class Hash
  def guarded(k, iname: 'item', kname: 'key')
    if self.has_key?(k)
      return self[k]
    else
      raise ArgumentError, "No such #{iname} by #{kname} '#{k}'"
    end
  end
end

