module ARKWEB

class Page
  def initialize(site, path, section)
    @site    = site
    @section = section
    @path    = path

    @index = 0

    @atime = File.atime(@path)
    @ctime = File.ctime(@path)
    @mtime = File.mtime(@path)

    @base        = File.basename(@path)
    @name        = @base[/^(.+?)\./, 1]
    @html        = "#{@name}.html"
    @relative    = Pathname.new(@path).relative_path_from(Pathname.new(@site.root)).to_s
    @relativedir = File.dirname(@relative)

    if @relativedir == '.'
      @link = File.join('/', @html)
    else
      @link = File.join('/', @relativedir, @html)
    end

    @out     = File.join(@site.out(:render), @link)
    @out_dir = File.dirname(@out)

    if @path[/\.erb$/]
      @erb  = true
      @type = @path[/^.+?\.(.+).erb$/, 1]
    else
      @erb  = false
      @type = @path[/^.+?\.(.+)$/, 1]
    end

    @text = File.open(@path, 'r') {|f| f.read }
    if (md = @text.match(/^(?<metadata>---\s*\n.*?\n?)^(---\s*$\n?)/m))
      @contents = md.post_match
      yaml = md[:metadata]
      box  = Engine::Sandbox.new(:site => @site)
      erb  = ERB.new(yaml)
      yaml = erb.result(box.bindings)
      @metadata = YAML.load(yaml)
      @has_metadata = true
    else
      @contents = @text
      @metadata = {}
      @has_metadata = false
    end

    @title = @metadata['title'] || @name.tr('-', ' ').split(/(\W)/).map(&:capitalize).join
    @tags = @metadata['keywords'] || @metadata['tags'] || []
    @collect = [@metadata['collect']].flatten.map(&:to_s)
    @pagesize = @metadata['pagesize']
    @pagesize = @pagesize.to_i if @pagesize
    @description = @metadata['description'] || nil

  end
  attr_reader :site, :path, :section
  attr_reader :base, :name, :out, :type
  attr_reader :out_dir, :title, :relativedir
  attr_reader :link
  attr_reader :contents, :has_metadata, :metadata
  attr_reader :atime, :ctime, :mtime
  attr_reader :collect
  attr_reader :pagesize
  attr_reader :description
  attr_accessor :index

  def has_erb?
    return @erb
  end

  def paginated_name(index)
    if index == 1
      index = ''
    else
      index = "-#{index}"
    end
    return "#{@name}#{index}"
  end

  def paginated_out(index)
    File.join(@site.out(:render), @relativedir, "#{self.paginated_name(index)}.html")
  end

  def paginated_link(index)
    File.join(File.dirname(@link), "#{self.paginated_name(index)}.html")
  end

  def link_to(text: @title, id: nil, klass: nil, index: nil)
    id    = %Q( id="#{id}")       if id
    klass = %Q( class="#{klass}") if klass

    if index
      link = self.paginated_link(index)
    else
      link = @link
    end

    return %Q(<a#{id}#{klass} href="#{link}">#{text}</a>)
  end

  def to_s
    return @link
  end

  def inspect
    return "<Page:#{self}>"
  end

  def <=>(b)
    @ctime <=> b.ctime
  end
end

end # module ARKWEB

