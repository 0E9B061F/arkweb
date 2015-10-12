module ARKWEB

class Image
  def initialize(site, input_path, page=nil)
    # Relations
    @site = site
    @page = page

    if self.site_image?
      @path = Path.new(@site, input_path, @site.output.images)
    else
      @path = Path.new(@site, input_path, @site.output.root, relative: true)
    end

    @name = @path.name
  end

  attr_reader :path
  attr_reader :name

  # True if this image is found in the ARKWEB directory. False if located
  # in the site structure.
  def site_image?
    return @page.nil?
  end

  def link_to(**attr)
    HTML.link_image(self, **attr)
  end

  # Represent this object as the working path to the given stylesheet
  def to_s()
    return @path.link
  end

  def inspect
    return "#<AW::Image:#{@path.link}>"
  end
end

end # module ARKWEB

