module ARKWEB

class Path
  # output dir should always be out(;render), hard set relative can be used to
  # give other dirs below this
  def initialize(site, input_path, output_root, relative: false, output_name: nil, output_ext: nil)
    @site = site
    @input = input_path

    if self.root?
      @basename = '/'
      @name = '/'
    else
      @basename = @input.basename.to_s
      @name = @basename[/^[^\.]+/]
    end

    @output_dir = @site.out(output_root)

    @input_relative = @input.relative_path_from(@site.root)

    @relative = @input_relative.dirname
    @relative = '' if @relative.to_s == '.'

    @output_name = output_name || @name
    @output_ext = output_ext || @input.extname
    if !@output_ext.empty? && !@output_ext[/^\./]
      @output_ext = ".#{@output_ext}"
    end
    @output_fullname = "#{@output_name}#{@output_ext}"

    @output = if relative
      @output_dir.join(@relative).join(@output_fullname)
    else
      @output_dir.join(@output_fullname)
    end

    root = Pathname.new('/')
    if self.root?
      @link = root
    else
      address = @output.relative_path_from(@site.out(:root))
      @link = root.join(address)
    end
  end
  attr_reader :input
  attr_reader :output
  attr_reader :input_relative
  attr_reader :link
  attr_reader :name
  attr_reader :basename

  
  #
  # Pagination
  #

  def paginated_name(index)
    if index == 1
      index = ''
    else
      index = "-#{index}"
    end
    return "#{@name}#{index}"
  end

  def paginated_output(index)
    name = self.paginated_name(index)
    return @output_dir + @relative + "#{name}#{@output_ext}"
  end

  def paginated_link(index)
    out = self.paginated_output(index)
    out = out.relative_path_from(@site.out(:root))
    return "/#{out}"
  end


  #
  # Utilities
  #

  # Has the input file changed since the output file was created?
  def changed?
    return !@output.exist? || @input.mtime > @output.mtime
  end

  def root?
    return @input == @site.root
  end


  #
  # Internal
  #

  def to_s
    return @link.to_s
  end

  def inspect
    return "#<AW::Path:#{self}>"
  end
end

end # module ARKWEB

