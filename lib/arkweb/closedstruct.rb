module ARKWEB

class ClosedStruct
  def initialize(**defaults, &block)
    @data = defaults
    @finalized = false
    yield self if block_given?
    @finalized = !@data.empty?
  end

  private

  def _get_data(k)
    k = k.to_sym
    if @data.has_key?(k)
      return @data[k]
    else
      raise NoMethodError, "#{self.inspect} has no attribute named '#{k.inspect}'"
    end
  end

  def _set_data(k,v)
    k = k.to_sym
    if @finalized && !@data.has_key?(k)
      raise NoMethodError, "Unable to modify a closed struct"
    else
      @data[k] = v
    end
  end

  public

  def [](k)
    _get_data(k)
  end

  def []=(k,v)
    _set_data(k,v)
  end

  def method_missing(id, *args, &block)
    if !id[/^_*[a-zA-Z]/]
      raise NoMethodError, "No such method: #{id}"
    elsif id[-1] == "="
      raise ArgumentError unless args.length == 1
      id = id[0..-2].to_sym
      _set_data(id, args[0])
    else
      raise ArgumentError, "#{id} accepts no arguments" if args.length > 0
      _get_data(id)
    end
  end

  def _each(&block)
    @data.each(&block)
  end

  def _data
    return @data.clone
  end

  def _update!(b)
    if b.is_a?(Hash)
      b_data = b
    elsif b.is_a?(ClosedStruct)
      b_data = b._data
    else
      raise TypeError, "Expected ClosedStruct or Hash"
    end
    b_data.each do |k,v|
      v = nil if v.is_a?(String) && v.empty?
      if !v.nil?
        begin
          _set_data(k.to_sym, v)
        rescue
        end
      end
    end
  end

  def _finalize!
    @finalized = true
  end

  def inspect
    f = @finalized ? '!' : nil
    %Q(#<AW::ClosedStruct#{f}:#{@data.keys.join(':')}>)
  end
end

end # module ARKWEB

