module ARKWEB

class Path
  def initialize(site, input_path, output_dir, relative: nil, output_name: nil, output_ext: nil)
    @site = site
    site_root = Pathname.new(@site.root)
    @input = Pathname.new(input_path)
    @basename = @input.basename.to_s
    @output_dir = Pathname.new(output_dir)
    @relative = relative || @input.relative_path_from(site_root).dirname
    @relative = '' if @relative.to_s == '.'
    @name = @input.basename.to_s[/^[^\.]+/]
    @output_name = output_name || @name
    @output_ext = output_ext || @input.extname
    @output = @output_dir + @relative + "#{@output_name}.#{@output_ext}"
    @render_root = Pathname.new(@site.out(:render))
    relative_out = @output.relative_path_from(@render_root)
    @link = "/#{relative_out}"
  end
  attr_reader :input
  attr_reader :output
  attr_reader :link
  attr_reader :name
  attr_reader :basename

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
    return @output_dir + @relative + "#{name}.#{@output_ext}"
  end

  def paginated_link(index)
    out = self.paginated_out(index)
    out = out.relative_path_from(@render_root)
    return "/#{out}"
  end

  def changed?
    return !@output.exist? || @input.mtime > @output.mtime
  end
end

end # module ARKWEB

