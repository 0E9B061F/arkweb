module ARKWEB

class Page
  include HasAssets

  def initialize(site, input_path, section, autoindex: false)
    @site    = site
    @section = section
    @autoindex = autoindex

    @composite = input_path.directory? && input_path.basename.to_s[/\.page$/]

    if @autoindex
      @path = Path.new(@site, input_path, @section.path.output, output_ext: 'html', output_name: 'index')
    elsif @composite
      index = input_path.first("index#{Site::Types.pages}")
      @path = Path.new(@site, index, @site.output.root, output_name: 'index', output_ext: 'html', relative: true, composite_page: true)
    else
      @path = Path.new(@site, input_path, @site.output.root, output_name: 'index', output_ext: 'html', relative: true, nest: true)
    end

    @name = if @composite
      @name = @path.input.dirname.basename.to_s
    else
      @name = @path.name
    end

    init_assets(@path.input.dirname)

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

    if self.index?
      title = "#{@section.title} Index"
    else
      title = @path.name.tr('-', ' ').split(/(\W)/).map(&:capitalize).join
    end

    paginate = autoindex ? 5 : false

    @conf = ClosedStruct.new(
      title: title,
      desc: false,
      keywords: [],
      collect: [@section.path.link],
      paginate: paginate,
      index: false,
      date: false
    )
    unless header.empty?
      header = Hash[header.map {|k,v| [k.to_sym, v] }]
      @conf._update!(header)
    end
    @conf.collect = [@conf.collect].flatten.map(&:to_s)

    @title = @conf.title
    @desc = @conf.desc || ''
    @collect = @conf.collect
    @paginate = @conf.paginate ? @conf.paginate.to_i : false

    @user_index = @conf.index || -1

    @date = if @conf.date
      @date = Time.parse(@conf.date)
    else
      @date = @path.input.ctime
    end
  end
  attr_reader :site
  attr_reader :path
  attr_reader :conf
  attr_reader :section
  attr_reader :type
  attr_reader :name
  attr_reader :title
  attr_reader :contents
  attr_reader :collect
  attr_reader :paginate
  attr_reader :desc
  attr_reader :date
  attr_reader :user_index
  attr_accessor :index

  private

  def descend(element, &block)
    element.children.each do |e|
      if e.text?
        e.content = e.content.strip
        yield e if e.content != ""
      end
      descend(e, &block)
    end
  end

  def snip_text(text, max)
    count = 0
    out = []
    done = false
    text.split(/\s+/).each do |word|
      new_count = count + word.length
      new_count += 1 if out.length > 0
      if new_count > max
        done = true
      else
        count = new_count
        out << word
      end
      break if done
    end
    return out.join(" ")
  end

  def snip_html(html, max)
    max -= 4
    count = 0
    erasing = false
    doc = Nokogiri::HTML(html)
    descend(doc) do |text|
      p = text.parent
      if erasing
        text.remove
        p.remove if p.text == ''
      elsif count + text.text.length > max
        text.content = snip_text(text.text, max - count)
        count += text.text.length
        erasing = true
      else
        count += text.text.length
      end
    end
    doc.traverse do |e|
      if e.element?
        if e.name[/^h[1-6]$/]
          e.name = "span"
          e["class"] = "aw-snippet-title"
        elsif e.name == "p" || e.name == "span"
          e["class"] = "aw-snippet-text"
        else
          e.remove_attribute("class")
        end
      end
    end
    textwise = []
    descend(doc) {|t| textwise << t }
    ellipsis = Nokogiri::XML::Node.new("span", doc)
    ellipsis.content = " ..."
    ellipsis["class"] = "aw-snippet-ellipsis"
    textwise.last.parent.add_child(ellipsis)
    wrap = Nokogiri::XML::Node.new("div", doc)
    wrap[:class] = "aw-snippet"
    doc.xpath('//body/*').each {|e| e.parent = wrap if e.element? }
    doc.xpath('//body').first.add_child(wrap)
    return doc.xpath('//body/*').to_html
  end

  public

  def configs
    @conf._data
  end

  def composite?
    return @composite
  end

  def rendered
    @rendered ||= Engine.render_page_contents(self)
  end

  def index?
    return @path.name == 'index' || @autoindex
  end

  def trail
    if index?
      return @section.path.link
    else
      return @path.link
    end
  end

  def snippet(max=200, wordwise=false)
    @snippet ||= if self.has_erb?
      snip_text(@desc, max)
    else
      snip_html(self.rendered, max)
    end
    return @snippet
  end

  def has_erb?
    return @erb
  end

  def link_to(**attr)
    return HTML.link_page(self, **attr)
  end

  def to_s
    return @path.input_relative.to_s
  end

  def inspect
    return %Q(#<AW::Page:"#{self}">)
  end

  def <=>(b)
    @date <=> b.date
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

  def paginate(index, sort: :date, ascending: true)
    index = index - 1
    first = index * @pagesize
    last  = first + (@pagesize - 1)
    pages = @pages.sort {|pa,pb| pa.send(sort) <=> pb.send(sort) }
    pages.reverse! unless ascending
    pages[first..last]
  end

  def links(index)
    links = []
    @range.each do |i|
      if i == index
        links << "<span class=\"pagination pagination-current\">#{index}</span>"
      else
        links << @page.link_to(text: i, class: 'pagination pagination-link', index: i)
      end
    end
    links.join("\n")
  end

  def inspect
    return "#<AW::Collection:[#{@page.collect.join(",")}]>"
  end
end

end # module ARKWEB

