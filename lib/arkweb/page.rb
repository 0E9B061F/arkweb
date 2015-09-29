module ARKWEB

class Page
  def initialize(site, input_path, section)
    @site    = site
    @section = section
    @path    = Path.new(@site, input_path, :root, output_ext: 'html', relative: true)

    @index = 0

    if @path.basename[/\.erb$/]
      @erb  = true
      @type = @path.basename[/^.+?\.(.+).erb$/, 1]
    else
      @erb  = false
      @type = @path.basename[/^.+?\.(.+)$/, 1]
    end

    data = @path.input.read
    if (md = data.match(/^(?<metadata>---\s*\n.*?\n?)^(---\s*$\n?)/m))
      @contents = md.post_match
      yaml = md[:metadata]
      box  = Engine::Sandbox.new(:site => @site)
      erb  = ERB.new(yaml)
      yaml = erb.result(box.bindings)
      header = YAML.load(yaml)
    else
      @contents = data
      header = {}
    end

    @conf = {
      :title => @path.name.tr('-', ' ').split(/(\W)/).map(&:capitalize).join,
      :desc => false,
      :keywords => [],
      :collect => [],
      :pagesize => false
    }
    unless header.empty?
      header = Hash[header.map {|k,v| [k.to_sym, v] }]
      @conf = @conf.merge(header) {|k,old,new| new && !new.to_s.empty? ? new : old }
    end
    @conf[:collect] = @conf[:collect].flatten.map(&:to_s)
    @conf[:pagesize] = @conf[:pagesize].to_i if @conf[:pagesize]

    @title = self.conf(:title)
    @desc = self.conf(:desc) || ''
    @collect = self.conf(:collect)
    @pagesize = self.conf(:pagesize) ? self.conf(:pagesize).to_i : false
  end
  attr_reader :site
  attr_reader :path
  attr_reader :section
  attr_reader :type
  attr_reader :title
  attr_reader :contents
  attr_reader :collect
  attr_reader :pagesize
  attr_reader :desc
  attr_accessor :index

  def conf(key)
    key = key.to_sym
    unless @conf.has_key?(key)
      raise ArgumentError "No such configuration: #{key}"
    end
    return @conf[key]
  end

  def has_erb?
    return @erb
  end

  def link_to(text: @title, id: nil, klass: nil, index: nil)
    id    = %Q( id="#{id}")       if id
    klass = %Q( class="#{klass}") if klass

    if index
      link = @path.paginated_link(index)
    else
      link = @path.link
    end

    return %Q(<a#{id}#{klass} href="#{link}">#{text}</a>)
  end

  def to_s
    return @path.link
  end

  def inspect
    return "#<AW::Page:#{self}>"
  end

  def <=>(b)
    @path.input.ctime <=> b.path.input.ctime
  end
end


class Collection
  def initialize(page, pages, pagesize)
    @page      = page
    @pages     = pages
    @pagesize  = pagesize
    @pagecount = (@pages.length / @pagesize.to_f).ceil
    @range     = (1..@pagecount)
  end

  attr_reader :range
  attr_reader :pagecount

  def paginate(index)
    index = index - 1
    first = index * @pagesize
    last  = first + (@pagesize - 1)
    @pages[first..last]
  end

  def links(index)
    links = []
    @range.each do |i|
      if i == index
        links << "<span class=\"pagination pagination-current\">#{index}</span>"
      else
        links << @page.link_to(text: i, klass: 'pagination pagination-link', index: i)
      end
    end
    links.join("\n")
  end

  def inspect
    return "#<AW::Collection:#{@page.collect.join(",")}>"
  end
end

end # module ARKWEB

