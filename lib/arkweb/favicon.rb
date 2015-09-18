module ARKWEB

class FaviconFormat
  def initialize(site, format, resolution, output_dir, name=nil)
    @site = site
    @format = format
    @resolution = resolution
    @output_dir = output_dir
    if name
      @name = name
    else
      @name = "favicon-#{@resolution}.#{@format}"
    end
    @output_path = File.join(@output_dir, @name)
    @link_path = @site.link_from_output(@output_path)
  end
  attr_reader :output_path
  attr_reader :link_path
  attr_reader :format
  attr_reader :resolution
  attr_reader :name
end

class Favicon
  def initialize(site, input_path)
    @site = site
    @input_path = input_path
    @formats = []
    @formats << FaviconFormat.new(@site, 'ico', '16x16',   @site.out(:render), 'favicon.ico')
    @formats << FaviconFormat.new(@site, 'png', '16x16',   @site.out(:favicons))
    @formats << FaviconFormat.new(@site, 'png', '32x32',   @site.out(:favicons))
    @formats << FaviconFormat.new(@site, 'png', '96x96',   @site.out(:favicons))
    @formats << FaviconFormat.new(@site, 'png', '192x192', @site.out(:favicons))
  end
  attr_reader :input_path
  attr_reader :formats
end

end # module ARKWEB

