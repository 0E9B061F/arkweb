module ARKWEB

class Helper
  def initialize(site, section, page)
    @site = site
    @page = page
    @section = section
  end

  # Create a span. Mostly meant for internal use
  def span(content, id: nil, klass: nil)
    id = %Q( id="#{id}") if id
    klass = %Q( class="#{klass}") if klass
    return %Q(<span#{id}#{klass}>#{content}</span>)
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
end

end # module ARKWEB

