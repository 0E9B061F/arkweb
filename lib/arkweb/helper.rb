module ARKWEB

class Helper
  def initialize(site, section, page)
    @site = site
    @page = page
    @section = section
  end

  private

  def mk_id(id=nil)
    return id ? %Q( id="#{id}") : nil
  end

  def mk_klass(klass=nil)
    return klass ? %Q( class="#{klass}") : nil
  end

  public

  # Create a span. Mostly meant for internal use
  def span(content, id: nil, klass: nil)
    id = mk_id(id)
    klass = mk_klass(klass)
    return %Q(<span#{id}#{klass}>#{content}</span>)
  end

  def list(items, ordered: false, id: nil, klass: nil, itemklass: nil)
    id = mk_id(id)
    klass = mk_klass(klass)
    itemklass = mk_klass(klass)
    tag = ordered ? "ol" : "ul"
    items.map! do |i|
      %Q(<li#{itemklass}>#{i}</li>)
    end
    return %Q(<#{tag}#{id}#{klass}>#{items.join}</#{tag}>)
  end

  # Return the full title for a given page, constructed from the site title,
  # section title and individual page title. Titles will be joined by
  # `seperator`
  def full_title(seperator=' - ')
    titles = [@site.title, @section.title, @page.title]
    titles.join(seperator)
  end

  # Return a full description for the current page, constructed from the site
  # description, section description and page description. Descriptions are
  # joined with spaces, and a period will be appended as needed.
  def full_description
    descs = [@site.desc, @section.desc, @page.desc]
    descs.reject {|d| d.empty? }.map {|d| !d.strip[/\.$/] ? d.strip.sub(/$/, '.') : d.strip  }.join(' ')
  end

  # Return a linked trail from the site root for the current page
  def trail(seperator=' > ')
    trail = []
    Pathname.new(@section.path.address).descend do |a|
      trail << @site.section(a).link_to(klass: "aw-trail-section")
    end
    trail << self.span(@page.title, klass: "aw-trail-page")
    seperator = self.span(seperator, klass: "aw-trail-seperator")
    trail = trail.join(seperator)
    return self.span(trail, klass: "aw-trail")
  end

  def list_pages(section: false, span: true, linked: true)
    if section
      section = @site.section(section)
    else
      section = @section
    end
    list = []
    section.pages.each do |p|
      if linked && p != @page
        list << p.link_to(klass: "aw-page-list-link")
      else
        list << self.span(p.title, klass: "aw-page-list-title")
      end
    end
    if span
      list = list.join(' ')
      return self.span(list, klass: "aw-page-list")
    else
      return self.list(list, klass: "aw-page-list")
    end
  end
end

end # module ARKWEB

