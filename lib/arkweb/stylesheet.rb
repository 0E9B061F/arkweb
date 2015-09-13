module ARKWEB

# This class represents a stylesheet, in CSS or one of the flavors of SASS. The
# stylesheet may be a site-wide style found in the ARKWEB directory, or a
# section-specific style found in the site structure.
class Stylesheet
  def initialize(site, working_path, section=nil)
    # Relations
    @site    = site
    @section = section

    # Path stuff
    # working_path: path to the file relative to the current working directory
    # site_path:    path relative to the site root
    # output_path:  path to the output location, relative to the current working directory
    # server_path:  path to the file when the output is served as a website; as if the site root were the filesystem root
    @working_path  = working_path
    @basename      = File.basename(@working_path)
    @name          = @basename[/^[^\.]+/]
    @extension     = @basename[/\..+$/]
    @rendered_name = "#{@name}.css"

    # The site_path isn't wholly necessary for site styles but we'll keep in either case, for consistency
    @site_path    = Pathname.new(@working_path).relative_path_from(Pathname.new(@site.root)).to_s

    if self.site_style?
      @output_path  = File.join(@site.output[:aw], @rendered_name)
      @aw_path      = Pathname.new(@output_path).relative_path_from(Pathname.new(@site.output[:render])).to_s
      @server_path  = File.join('/', @aw_path)
    else
      site_dirname  = File.dirname(@site_path)
      rendered_path = File.join(site_dirname, @rendered_name)
      @output_path  = File.join(@site.output[:render], rendered_path)
      @server_path  = File.join('/', rendered_path)
    end
  end

  attr_reader :basename
  attr_reader :name
  attr_reader :working_path
  attr_reader :output_path
  attr_reader :server_path

  # True if this stylesheet is found in the ARKWEB directory. False if located
  # in the site structure.
  def site_style?
    return @section.nil?
  end

  # Return true if this stylesheet is in SASS
  def is_sass?
    return !@basename[/\.s[ca]ss$/].nil?
  end

  def is_css?
    return !self.is_sass?
  end

  # Represent this object as the working path to the given stylesheet
  def to_s()
    return @working_path
  end

  # Return a link to this stylesheet
  def head_link()
    return %Q(<link href="#{@server_path}" rel="stylesheet" type="text/css" />)
  end
end

end # module ARKWEB

