module ARKWEB

class Helper
  def initialize(site, section, page)
    @site = site
    @page = page
    @section = section
  end

  def full_title
    titles = [@site.title, @section.title, @page.title]
    titles.join(' - ')
  end

  def full_description
    descs = [@site.desc, @section.desc, @page.desc]
    descs.reject {|d| d.empty? }.map {|d| !d.strip[/\.$/] ? d.strip.sub(/$/, '.') : d.strip  }.join(' ')
  end

end

end # module ARKWEB

