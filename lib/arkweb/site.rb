module ARKWEB

class Site

  RootSectionName = 'root'
  InputARKWEB     = 'AW'
  OutputARKWEB    = 'AW'

  Types = {
    :pages    => "*.{erb,md,html,wiki}",
    :images   => "*.{jpg,jpeg,png,gif}",
    :style    => "*.{css,scss,sass}",
    :sass     => "*.{scss,sass}",
    :css      => "*.css",
    :icon     => "icon.{png,gif,ico,jpg,jpeg}"
  }

  FontService = {
    :google => lambda {|fonts|
      url = 'https://fonts.googleapis.com/css?family='
      fonts = fonts.join('|')
      return [url + fonts]
    },
    :fontsquirrel => lambda {|fonts|
      fonts.map {|font| File.join('/', OutputARKWEB, "#{font}.css") }
    }
  }

  def initialize(interface, root)

    # Basics
    @interface = interface
    raise BrokenSiteError unless File.directory?(root)
    @root = root
    @name = File.basename(root)

    # Paths to special input directories and files
    @input = {}
    @input[:arkweb]       = File.join(@root, InputARKWEB)
    @input[:header]       = File.join(@input[:arkweb], 'header.yaml')
    @input[:page_erb]     = File.join(@input[:arkweb], 'page.html.erb')
    @input[:site_erb]     = File.join(@input[:arkweb], 'site.html.erb')
    @input[:style]        = File.join(@input[:arkweb], 'site.{css,sass,scss}')
    @input[:images]       = File.join(@input[:arkweb], 'images')
    @input[:hooks]        = File.join(@input[:arkweb], 'hook')
    @input[:before_hooks] = File.join(@input[:hooks], 'before')
    @input[:after_hooks]  = File.join(@input[:hooks], 'after')

    # Load the header
    begin
      header = YAML.load_file(@input[:header])
    rescue => e
      raise BrokenSiteError,
      "While loading site '#{@root}': #{e}\nHeader file '#{@input[:header]}' is missing or malformed."
    end

    # Configure details about the site
    @conf = {}
    @conf[:author]    = header['author']
    @conf[:title]     = header['title']
    @conf[:desc]      = header['desc'] || header['description']
    @conf[:tags]      = header['tags'] || header['keywords'] || []
    @conf[:tags]      = @conf[:tags].join(", ")
    @conf[:tags]      = nil if @conf[:tags].empty?
    @conf[:keywords]  = @conf[:tags]
    @conf[:xuacompat] = header['xuacompat'] || false
    @conf[:webfonts]  = {'google' => [], 'fontsquirrel' => []}
    @conf[:webfonts]  = @conf[:webfonts].merge(header['webfonts']) if header['webfonts']

    # Finish with input paths
    @input[:styles] = header['styles'] || Dir[File.join(@input[:arkweb], Types[:style])]

    # Paths to where output files should be rendered
    @output = {}
    @output[:tmp]      = header['tmp']   || File.join(@input[:arkweb], 'tmp')
    @output[:cache]    = header['cache'] || File.join(@input[:arkweb], 'cache')
    @output[:render]   = @interface.conf.opt(:output) || header['output'] || File.join(@input[:arkweb], 'output')
    @output[:aw]       = File.join(@output[:render], OutputARKWEB)
    @output[:images]   = File.join(@output[:aw], 'images')
    @output[:fonts]    = File.join(@output[:aw], 'fonts')
    @output[:favicons] = File.join(@output[:aw], 'favicons')

    # Collect paths to each hook
    @before_hooks = Dir[File.join(@input[:before_hooks], '*')]
    @after_hooks = Dir[File.join(@input[:after_hooks], '*')]

    # Look for a favicon
    favicon_path = Dir[File.join(@input[:arkweb], Types[:icon])].first
    if favicon_path
      @favicon = Favicon.new(self, favicon_path)
    else
      @favicon = nil
    end

    @font_styles = []
    if @conf[:webfonts]['fontsquirrel']
      @conf[:webfonts]['fontsquirrel'].map! {|f| f.tr(' ', '-') }
    end
    @conf[:webfonts].each do |service,fonts|
      service = service.to_sym
      if FontService[service]
        unless fonts.empty?
          @font_styles += FontService[service][fonts]
        end
      else
        wrn "Unknown font provider '#{service}' for fonts: #{fonts}"
      end
    end

    @images = Dir[File.join(@input[:images], Types[:images])]

    sheets = Dir[File.join(@input[:arkweb], Types[:style])]
    @styles = {}
    sheets.each do |s|
      s = Stylesheet.new(self, s)
      @styles[s.name] = s
    end

    # Return a list of sections, which are any subdirectories excluding special subdirectories
    # The root directory is itself a section
    # Each section will later be scanned for pages and media, and then rendered
    subdirs = Dir[File.join(@root, '**/')].reject do |path|
      path.start_with?(@input[:arkweb])
    end
    @sections = {}
    @pages = []
    subdirs.each do |path|
      s = Section.new(self, path)
      address = Pathname.new(path).relative_path_from(Pathname.new(@root)).to_s
      address = address.sub(/^[\.\/]+/, '')
      address = address.sub(/\/+$/, '')
      address = RootSectionName if address == ''
      @sections[address] = s
      @pages += s.pages
    end

    [:render, :tmp, :images, :cache].each do |dir|
      FileUtils.mkdir_p(@output[dir])
    end

    @engine = Engine.new(self)
  end

  attr_reader :interface
  attr_reader :engine
  attr_reader :root
  attr_reader :name
  attr_reader :input
  attr_reader :output
  attr_reader :conf
  attr_reader :styles
  attr_reader :pages
  attr_reader :sections
  attr_reader :webfonts
  attr_reader :images
  attr_reader :before_hooks
  attr_reader :after_hooks
  attr_reader :favicon

  def info(key)
    @conf[key.to_sym]
  end

  # Convenience method for accessing +@input+
  def in(key)
    @input[key.to_sym]
  end

  # Convenience method for accessing +@output+
  def out(key)
    @output[key.to_sym]
  end

  def link_from_output(path)
    Pathname.new(path).relative_path_from(Pathname.new(@output[:render])).to_s
  end

  def img(name, alt: nil, id: nil, klass: nil)
    alt   = %Q( alt="#{alt}")     if alt
    id    = %Q( id="#{id}")       if id
    klass = %Q( class="#{klass}") if klass

    link = Pathname.new(@output[:images]).relative_path_from(Pathname.new(@output[:render]))
    link = File.join('/', link, name)

    return %Q(<img#{id}#{klass}#{alt} src="#{link}" />)
  end

  def link_styles
    @styles.map {|n,s| s.head_link }.join("\n")
  end

  def link_webfonts
    links = []
    @font_styles.each do |path|
      links << %Q(<link href="#{path}" rel="stylesheet" type="text/css" />)
    end
    return links.join("\n")
  end

  def link_favicons
    if !@favicon.nil?
      links = []
      @favicon.formats.each do |format|
        unless format.format == 'ico'
          links << %Q(<link rel="icon" type="image/#{format.format}" sizes="#{format.resolution}" href="#{format.link_path}">)
        end
      end
      return links.join("\n")
    end
  end

  def meta(name, content)
    if name && content
      return %Q(<meta name="#{name}" content="#{content}" />)
    end
  end

end # class Site
end # module ARKWEB

