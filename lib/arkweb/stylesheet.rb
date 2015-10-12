module ARKWEB

# This class represents a stylesheet, in CSS or one of the flavors of SASS. The
# stylesheet may be a site-wide style found in the ARKWEB directory, or a
# section-specific style found in the site structure.
class Stylesheet
  def initialize(site, input_path, page=nil)
    # Relations
    @site = site
    @page = page

    if self.site_style?
      @path = Path.new(@site, input_path, @site.output.aw, output_ext: 'css')
    else
      @path = Path.new(@site, input_path, @site.output.root, output_ext: 'css', relative: true)
    end

    @name = @path.name
  end

  attr_reader :path
  attr_reader :name

  # True if this stylesheet is found in the ARKWEB directory. False if located
  # in the site structure.
  def site_style?
    return @page.nil?
  end

  # Return true if this stylesheet is in SASS
  def is_sass?
    return !@path.basename[/\.s[ca]ss$/].nil?
  end

  def is_css?
    return !self.is_sass?
  end

  # Represent this object as the working path to the given stylesheet
  def to_s()
    return @path.input_relative.to_s
  end

  # Return a link to this stylesheet
  def link_to()
    HTML.link_to(self)
  end

  def inspect
    return "#<AW::Stylesheet:#{self}>"
  end
end

end # module ARKWEB

