module ARKWEB

class Script
  def initialize(site, input_path, page=nil)
    # Relations
    @site = site
    @page = page

    if self.site_script?
      @path = Path.new(@site, input_path, @site.output.scripts)
    else
      @path = Path.new(@site, input_path, @site.output.root, relative: true)
    end

    @name = @path.name
  end

  attr_reader :path
  attr_reader :name

  # True if this image is found in the ARKWEB directory. False if located
  # in the site structure.
  def site_script?
    return @page.nil?
  end

  def head_link
    return %Q(<script src="#{@path.link}"></script>)
  end

  # Represent this object as the working path to the given stylesheet
  def to_s()
    return @path.link
  end

  def inspect
    return "#<AW::Script:#{@path.link}>"
  end
end

end # module ARKWEB

