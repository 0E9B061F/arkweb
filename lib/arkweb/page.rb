module ARKWEB

class Page
  def initialize(site, path, section)
    @site = site
    @section = section

    @path = path

    @index = 0

    @atime = File.atime(@path)
    @ctime = File.ctime(@path)
    @mtime = File.mtime(@path)

    @text = File.open(@path, 'r') {|f| f.read }
    if (md = @text.match(/^(?<metadata>---\s*\n.*?\n?)^(---\s*$\n?)/m))
      @contents = md.post_match
      @metadata = YAML.load(md[:metadata])
      @has_metadata = true
    else
      @contents = @text
      @metadata = {}
      @has_metadata = false
    end

    @base  = File.basename(@path)
    @name  = @base[/(.+)\..+?\.page$/, 1]
    @title = @metadata['title'] || @name.tr('-', ' ').split(/(\W)/).map(&:capitalize).join
    @tags  = @metadata['keywords'] || @metadata['tags'] || []

    @relative = Pathname.new(@path).relative_path_from(Pathname.new(@site.root))
    @relativedir = File.dirname(@relative)

    @html = "#{@name}.html"

    @link = File.join('/', @relativedir, @html)

    @out  = File.join(@site.output[:render], @link)
    @out_dir = File.dirname(@out)

    @type = @path[/\.(.+)\.page$/, 1]
  end
  attr_reader :site, :path, :section
  attr_reader :base, :name, :out, :type
  attr_reader :out_dir, :title, :relativedir
  attr_reader :link
  attr_reader :contents, :has_metadata, :metadata
  attr_reader :atime, :ctime, :mtime
  attr_accessor :index

  def link_to(**options)
    text  = options[:text]  || @title
    id    = options[:id]    || nil
    klass = options[:class] || nil
    id    = %Q( id="#{id}")       if id
    klass = %Q( class="#{klass}") if klass
    return %Q(<a#{id}#{klass} href="#{@link}">#{text}</a>)
  end

  def to_s()
    return @path
  end
end

end # module ARKWEB

