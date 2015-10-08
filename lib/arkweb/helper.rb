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
end

end # module ARKWEB

