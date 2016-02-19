module ARKWEB

class HTML

  def self.link_section(section, text: nil, **attr)
    text = text || section.title
    a(text, section.path.link, **attr)
  end

  def self.link_page(page, text: nil, index: nil, **attr)
    text = text || page.title
    if index
      a(text, page.path.paginated_link(index), **attr)
    elsif page.index?
      a(text, page.section.path.link, **attr)
    else
      a(text, page.path.link, **attr)
    end
  end

  def self.link_style(style, **attr)
    link(style.path.link, rel: 'stylesheet', type: 'text/css', **attr)
  end

  def self.link_script(script, **attr)
    script(script.path.link, **attr)
  end

  def self.link_image(image, **attr)
    img(image.path.link, **attr)
  end

  def self.link_favicon(favicon, **attr)
    links = []
    favicon.formats.each do |format|
      links << link_format(format, **attr) unless format.format == 'ico'
    end
    links.join("\n")
  end

  def self.link_format(format, **attr)
    link(format.path.link, rel: 'icon',
      type: "image/#{format.format}",
      sizes: format.resolution,
      **attr
    )
  end

  # Create an appropriate tag for a given resource
  def self.link_to(object, **attr)
    case object
    when ARKWEB::Section
      link_section(object, **attr)
    when ARKWEB::Page
      link_page(object, **attr)
    when ARKWEB::Stylesheet
      link_style(object, **attr)
    when ARKWEB::Script
      link_script(object, **attr)
    when ARKWEB::Image
      link_image(object, **attr)
    when ARKWEB::Favicon
      link_favicon(object, **attr)
    when ARKWEB::FaviconFormat
      link_format(object, **attr)
    else
      raise ArgumentError, "Cannot link to resource of class '#{object.class}'"
    end
  end

  def self.meta(name, content, **attr)
    open_tag(:meta, name: name, content: content, **attr)
  end

  def self.link(addr, **attr)
    open_tag(:link, href: addr, **attr)
  end

  def self.script(addr, **attr)
    tag(:script, src: addr, **attr)
  end

  def self.a(content, addr, **attr)
    tag(:a, content, href: addr, **attr)
  end

  def self.img(addr, **attr)
    open_tag(:img, src: addr, **attr)
  end

  # Create a span
  def self.span(content, **attr)
    tag(:span, content, **attr)
  end

  # Create a list form an array of items. List items can be customized by giving
  # a block. Each item will be yielded to the block and the return value will be
  # inserted into the list.
  def self.list(items, ordered: false, itemclass: nil, **attr, &block)
    tagname = ordered ? "ol" : "ul"
    items.map! do |i|
      if block_given?
        yield i
      else
        tag(:li, i, class: itemclass)
      end
    end
    tag(tagname, items.join, **attr)
  end

  def self.trpair(key, value, **attr)
    row  = tag(:th, key)
    row += tag(:td, value)
    return tag(:tr, row)
  end

  def self.attr(k,v)
    %Q( #{k}="#{v}")
  end

  def self.open_tag(name, **attr)
    tag(name, nil, **attr)
  end

  def self.tag(name, content='', **attr)
    attr = attr.map {|k,v| attr(k,v) }.join
    if content.nil?
      return %Q(<#{name}#{attr}>)
    else
      return %Q(<#{name}#{attr}>#{content}</#{name}>)
    end
  end

end


class Helper
  def initialize(site, section, page, collection, index)
    @site = site
    @page = page
    @section = section
    @collection = collection
    @index = index
  end

  def pagination(**opts)
    out = ""
    @collection.paginate(@index, **opts).each do |page|
      entry = ""
      date = page.date.strftime("%B %e, %Y")
      tags = page.conf[:keywords].join(", ")
      tags = "Tags: #{tags}"
      entry += HTML.tag(:h3, page.link_to, class: "aw-page-title")
      entry += HTML.tag(:span, date, class: "aw-page-date")
      entry += HTML.open_tag(:br)
      unless page.section == @section
        entry += HTML.tag(:span, "From: #{page.section.link_to}", class: "aw-page-section")
        entry += HTML.open_tag(:br)
      end
      unless page.conf[:keywords].empty?
        entry += HTML.tag(:span, tags, class: "aw-page-tags")
        entry += HTML.open_tag(:br)
      end
      unless page.empty?
        entry += HTML.tag(:div, page.snippet, class: "aw-page-desc")
      end
      out += HTML.tag(:div, entry, class: "aw-page-preview")
    end
    out += HTML.tag(:span, "Go to page: #{@collection.links(@index)}")
    return out
  end

  def debug_page
    out = ""
    out += HTML.tag(:caption, "Debug page: #{@page.path.link}")
    out += HTML.tag(:tr, HTML.tag(:th, "Attributes", class: "aw-debug-subheading", colspan: 2))
    out += HTML.trpair("Input path", @page.path.input)
    out += HTML.trpair("Output path", @page.path.output)
    out += HTML.trpair("Section", @page.section.link_to)
    out += HTML.trpair("Derived date", @page.date.strftime("%B %e, %Y"))
    out += HTML.trpair("ERB pass", @page.has_erb?)
    out += HTML.trpair("Markup type", @page.type)
    out += HTML.tag(:tr, HTML.tag(:th, "Header", class: "aw-debug-subheading", colspan: 2))
    @page.conf._data.each do |key,val|
      if val.is_a?(Array)
        out += HTML.trpair(key.to_s.capitalize, val.join(", "))
      elsif val.is_a?(Hash)
        unless val.empty?
          out += HTML.tag(:tr, HTML.tag(:th, key.to_s.capitalize, class: "aw-debug-subheading", colspan: 2))
          val.each do |k,v|
            out += HTML.trpair(k.to_s.capitalize, v)
          end
        end
      else
        out += HTML.trpair(key.to_s.capitalize, val)
      end
    end
    out += HTML.tag(:tr, HTML.tag(:th, "Assets", class: "aw-debug-subheading", colspan: 2))
    @page.assets._data.each do |key,val|
      key = key.to_s.capitalize
      if val.is_a?(Array)
        out += HTML.trpair(key, val.join(", "))
      elsif val.is_a?(Hash)
        out += HTML.tag(:tr, HTML.tag(:th, key))
        val.each do |k,v|
          out += HTML.trpair(k.to_s.capitalize, v.to_s)
        end
      else
        out += HTML.trpair(key, val)
      end
    end
    HTML.tag(:table, out, class: "aw-debug aw-debug-page")
  end

  # Return the full title for a given page, constructed from the site title,
  # section title and individual page title. Titles will be joined by
  # `seperator`
  def full_title(seperator=' - ')
    titles = []
    titles << @site.title
    titles << @section.title unless @section.root?
    titles << @page.title unless @page.index?
    return titles.join(seperator)
  end

  # Return a full description for the current page, constructed from the site
  # description, section description and page description. Descriptions are
  # joined with spaces, and a period will be appended as needed.
  def full_description
    descs = [@site.desc, @section.desc, @page.desc]
    descs.reject {|d| d.empty? }.map do |d|
      d = d.strip
      d[/\.$/] ? d : d.sub(/$/, '.')
    end.join(' ')
  end

  # Return a linked trail from the site root for the current page
  def trail(seperator=' > ', show_current: true)
    trail = []
    @page.trail.descend do |a|
      trail << a
    end
    last = @site.addr(trail.pop).title
    trail.map! {|a| @site.section(a).link_to(class: "aw-trail-section") }
    if show_current
      trail << HTML.span(last, class: "aw-trail-page")
    end
    seperator = HTML.span(seperator, class: "aw-trail-seperator")
    trail = trail.join(seperator)
    return HTML.span(trail, class: "aw-trail")
  end

  def list_pages(section: false, span: true, linked: true, hide_current: false, exclude_index: true, sort: :date, ascending: true, limit: false, ellipsis: true)
    if section
      section = @site.section(section)
    else
      section = @section
    end
    list = []
    pages = section.pages.sort {|pa,pb| pa.send(sort) <=> pb.send(sort) }
    pages.reverse! unless ascending
    pages = pages.take(limit) if limit
    pages.each do |p|
      unless (p == @page && hide_current) || (exclude_index && p.index?)
        if linked && p != @page
          list << p.link_to(class: "aw-page-list-link")
        else
          list << HTML.span(p.title, class: "aw-page-list-title")
        end
      end
    end
    if pages.length < section.pages.length
      list << section.link_to(text: '...')
    end
    if span
      list = list.join(' ')
      return HTML.span(list, class: "aw-page-list")
    else
      return HTML.list(list, class: "aw-page-list")
    end
  end

  def link_styles
    site_styles = @site.styles.map {|css| css.link_to }
    page_styles = @page.styles.map {|css| css.link_to }
    styles = site_styles + page_styles
    return styles.join("\n")
  end

  def link_scripts
    page_scripts = @page.scripts.map {|js| js.link_to }
    return page_scripts.join("\n")
  end

  def link_google_fonts
    if @site.conf.google_fonts
      fonts = @site.conf.google_fonts.map {|f| f.tr(' ', '+') }.join('|')
      url = "https://fonts.googleapis.com/css?family=#{fonts}"
      HTML.link(url, rel: 'stylesheet', type: 'text/css')
    end
  end

  def link_favicons
    if @site.assets.favicon
      @site.assets.favicon.link_to
    end
  end

  def insert_analytics
    if @site.conf.analytics_key
      return <<-JAVASCRIPT
      <script>
        (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
        (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
        m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
        })(window,document,'script','//www.google-analytics.com/analytics.js','ga');
        ga('create', '#{@site.conf(:analytics_key)}', 'auto');
        ga('send', 'pageview');
      </script>
      JAVASCRIPT
    end
  end

  def meta(name, content)
    if name && !name.to_s.empty? && content && !content.to_s.empty?
      HTML.meta(name, content)
    end
  end
end

end # module ARKWEB

