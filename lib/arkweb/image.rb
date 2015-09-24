module ARKWEB

class Image
  def initialize(site, input_path, section=nil)
    # Relations
    @site    = site
    @section = section

    if self.site_style?
      @path = Path.new(@site, input_path, :images)
    else
      @path = Path.new(@site, input_path, :root, relative: true)
    end

    @name = @path.name
  end

  attr_reader :path
  attr_reader :name

  # True if this image is found in the ARKWEB directory. False if located
  # in the site structure.
  def site_image?
    return @section.nil?
  end

  # Represent this object as the working path to the given stylesheet
  def to_s()
    return @path.link
  end

  def inspect
    return "#<Image:#{@path.link}>"
  end
end

end # module ARKWEB

