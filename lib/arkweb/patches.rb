class Pathname
  def glob(str)
    Dir[self + str].map {|p| Pathname.new(p) }
  end

  def first(str)
    self.glob(str).first
  end
end

