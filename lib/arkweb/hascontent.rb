module ARKWEB

module HasContent
  def page(name)
    @pages[name]
  end

  def pages
    @pages.values
  end

  def members
    @pages.values.reject {|page| page.index? }
  end

  def indices
    @pages.values.select {|page| page.index? }
  end

  def has_page?(name)
    @pages.has_key?(name)
  end

  def page_count
    @pages.length
  end

  def section(name)
    @sections[name]
  end

  def sections
    @sections.values
  end

  def ordered_pages
    @ordered
  end

  def ordered_members
    @ordered.reject {|p| p.index? }
  end
end

end # module ARKWEB

