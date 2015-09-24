module ARKWEB

class Path
  # output dir should always be out(;render), hard set relative can be used to
  # give other dirs below this
  def initialize(site, input_path, output_root, relative: false, output_name: nil, output_ext: nil)
    @site = site
    site_root = Pathname.new(@site.root)
    @input = Pathname.new(input_path)
    @basename = @input.basename.to_s
    @name = @basename[/^[^\.]+/]

    @output_dir = @site.out(output_root)
    @tmp_dir = @site.tmp(output_root)

    if relative
      @relative = @input.relative_path_from(site_root).dirname
      @relative = '' if @relative.to_s == '.'
    else
      @relative = ''
    end

    @output_name = output_name || @name
    @output_ext = output_ext || @input.extname
    if !@output_ext.empty? && !@output_ext[/^\./]
      @output_ext = ".#{@output_ext}"
    end

    @fullname = "#{@output_name}#{@output_ext}"

    @output = @output_dir + @relative + @fullname
    @tmp = @tmp_dir + @relative + @fullname

    @render_root = Pathname.new(@site.out(:root))
    @address = @output.relative_path_from(@render_root).to_s
    @link = "/#{@address}"
  end
  attr_reader :input
  attr_reader :output
  attr_reader :tmp
  attr_reader :link
  attr_reader :name
  attr_reader :basename
  attr_reader :address

  
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

  def paginated_tmp(index)
    name = self.paginated_name(index)
    return @tmp_dir + @relative + "#{name}#{@output_ext}"
  end

  def paginated_output(index)
    name = self.paginated_name(index)
    return @output_dir + @relative + "#{name}#{@output_ext}"
  end

  def paginated_link(index)
    out = self.paginated_output(index)
    out = out.relative_path_from(@render_root)
    return "/#{out}"
  end


  #
  # Utilities
  #

  # Has the input file changed since the output file was created?
  def changed?
    return !@output.exist? || @input.mtime > @output.mtime
  end


  #
  # Internal
  #

  def inspect
    return "#<Path:#{@link}>"
  end
end

end # module ARKWEB

