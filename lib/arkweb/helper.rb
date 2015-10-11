module ARKWEB

class HTML

  def self.link_to(object, text: nil, id: nil, klass: nil, index: nil)
    id = mk_id(id)
    klass = mk_klass(klass)

    text = object.title unless text

    if index
      link = object.path.paginated_link(index)
    else
      if object.is_a?(Page) && object.index?
        link = object.section.path.link
      else
        link = object.path.link
      end
    end

    return %Q(<a#{id}#{klass} href="#{link}">#{text}</a>)
  end

  # Create a span. Mostly meant for internal use
  def self.span(content, id: nil, klass: nil)
    id = mk_id(id)
    klass = mk_klass(klass)
    return %Q(<span#{id}#{klass}>#{content}</span>)
  end

  def self.list(items, ordered: false, id: nil, klass: nil, itemklass: nil)
    id = mk_id(id)
    klass = mk_klass(klass)
    itemklass = mk_klass(klass)
    tag = ordered ? "ol" : "ul"
    items.map! do |i|
      %Q(<li#{itemklass}>#{i}</li>)
    end
    return %Q(<#{tag}#{id}#{klass}>#{items.join}</#{tag}>)
  end

  def self.mk_id(id=nil)
    return id ? %Q( id="#{id}") : nil
  end

  def self.mk_klass(klass=nil)
    return klass ? %Q( class="#{klass}") : nil
  end

end


class Helper
  def initialize(site, section, page)
    @site = site
    @page = page
    @section = section
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
    descs.reject {|d| d.empty? }.map {|d| !d.strip[/\.$/] ? d.strip.sub(/$/, '.') : d.strip  }.join(' ')
  end

  # Return a linked trail from the site root for the current page
  def trail(seperator=' > ', show_current: true)
    trail = []
    @page.trail.descend do |a|
      trail << a
    end
    last = @site.addr(trail.pop).title
    trail.map! {|a| @site.section(a).link_to(klass: "aw-trail-section") }
    if show_current
      trail << HTML.span(last, klass: "aw-trail-page")
    end
    seperator = HTML.span(seperator, klass: "aw-trail-seperator")
    trail = trail.join(seperator)
    return HTML.span(trail, klass: "aw-trail")
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
          list << p.link_to(klass: "aw-page-list-link")
        else
          list << HTML.span(p.title, klass: "aw-page-list-title")
        end
      end
    end
    if pages.length < section.pages.length
      list << section.link_to(text: '...')
    end
    if span
      list = list.join(' ')
      return HTML.span(list, klass: "aw-page-list")
    else
      return HTML.list(list, klass: "aw-page-list")
    end
  end

  def link_styles
    site_styles = @site.styles.map {|n,s| s.head_link }
    page_styles = @page.styles.map {|s| s.head_link }
    styles = site_styles + page_styles
    return styles.join("\n")
  end

  def link_scripts
    page_scripts = @page.scripts.map {|s| s.head_link }
    return page_scripts.join("\n")
  end

  def link_google_fonts
    if @site.conf.google_fonts
      fonts = @site.conf.google_fonts.map {|f| f.tr(' ', '+') }.join('|')
      url = "https://fonts.googleapis.com/css?family=#{fonts}"
      return %Q(<link href="#{url}" rel="stylesheet" type="text/css" />)
    end
  end

  def link_favicons
    if !@site.favicon.nil?
      links = []
      @site.favicon.formats.each do |format|
        unless format.format == 'ico'
          links << %Q(<link rel="icon" type="image/#{format.format}" sizes="#{format.resolution}" href="#{format.path.link}">)
        end
      end
      return links.join("\n")
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
    if name && content
      return %Q(<meta name="#{name}" content="#{content}" />)
    end
  end
end

end # module ARKWEB

