class Pathname
  def glob(str)
    Dir[self + str].map {|p| Pathname.new(p) }
  end
end

