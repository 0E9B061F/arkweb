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

  def initialize(root, conf=nil)

    # Basics
    @app = Application.new
    @root = Pathname.new(root)
    raise BrokenSiteError unless @root.directory?
    @name = @root.basename

    # Paths to special input directories and files
    @input = {}
    @input[:arkweb]       = @root + InputARKWEB
    @input[:header]       = @input[:arkweb].join('header.yaml')
    @input[:page_erb]     = @input[:arkweb].join('page.html.erb')
    @input[:site_erb]     = @input[:arkweb].join('site.html.erb')
    @input[:style]        = @input[:arkweb].join('site.{css,sass,scss}')
    @input[:images]       = @input[:arkweb].join('images')
    @input[:hooks]        = @input[:arkweb].join('hook')
    @input[:before_hooks] = @input[:hooks].join('before')
    @input[:after_hooks]  = @input[:hooks].join('after')

    # Load the header
    begin
      header = YAML.load_file(@input[:header])
    rescue => e
      raise BrokenSiteError,
      "While loading site '#{@root}': #{e}\nHeader file '#{@input[:header]}' is missing or malformed."
    end
    header = Hash[header.map {|k,v| [k.to_sym, v] }]

    # Configure details about the site
    defaults = {
      :title => 'Untitled',
      :author => false,
      :desc => false,
      :keywords => false,
      :google_fonts => false,
      :xuacompat => false,
      :analytics_key => false,
      :clean => false,
      :clobber => false,
      :minify => false,
      :validate => false,
      :deploy => false,
      :output => false,
      :tmp => false,
      :cache => false
    }
    @conf = defaults
    if conf
      opts = Hash[conf.opts.map {|k,v| [k.to_sym, v] }]
      @conf = @conf.merge(opts) {|k,old,new| new && !new.to_s.empty? ? new : old }
    end
    @conf = @conf.merge(header) {|k,old,new| new && !new.to_s.empty? ? new : old }
    @conf.select! {|k,v| defaults.keys.member?(k) }

    # Paths to where output files should be rendered
    @output = {}
    @output[:tmp]      = @conf[:tmp]    || @input[:arkweb].join('tmp')
    @output[:cache]    = @conf[:cache]  || @input[:arkweb].join('cache')
    @output[:render]   = @conf[:output] || @input[:arkweb].join('output')
    @output[:aw]       = @output[:render].join(OutputARKWEB)
    @output[:images]   = @output[:aw].join('images')
    @output[:fonts]    = @output[:aw].join('fonts')
    @output[:favicons] = @output[:aw].join('favicons')

    # Decide what templates we'll be using
    if @input[:site_erb].exist?
      @site_template = @input[:site_erb]
    else
      @site_template = @app.root('templates/site.html.erb')
    end
    if @input[:page_erb].exist?
      @page_template = @input[:page_erb]
    else
      @page_template = false
    end

    # Collect paths to each hook
    @before_hooks = []
    @after_hooks = []
    if @input[:before_hooks].exist?
      @before_hooks = @input[:before_hooks].children.select {|c| c.executable? }
    end
    if @input[:after_hooks].exist?
      @after_hooks = @input[:after_hooks].children.select {|c| c.executable? }
    end

    # Look for a favicon
    favicon_path = @input[:arkweb].glob(Types[:icon]).first
    if favicon_path
      @favicon = Favicon.new(self, favicon_path)
    else
      @favicon = nil
    end
   
    # Get all images in the image dir
    @images = @input[:images].glob(Types[:images])

    # Get all stylesheets in the AW dir
    sheets = @input[:arkweb].glob(Types[:style])
    @styles = {}
    sheets.each do |s|
      s = Stylesheet.new(self, s)
      @styles[s.name] = s
    end

    # Return a list of sections, which are any subdirectories excluding special subdirectories
    # The root directory is itself a section
    # Each section will later be scanned for pages and media, and then rendered
    subdirs = []
    @root.find do |path|
      if path.directory?
        if path == @input[:arkweb] || path.basename.to_s[/^\./]
          Find.prune
        else
          subdirs << path
        end
      end
    end
    @sections = {}
    @pages = []
    subdirs.each do |path|
      s = Section.new(self, path)
      address = path.relative_path_from(@root).to_s
      address = RootSectionName if address == '.'
      @sections[address] = s
      @pages += s.pages
    end

    [:render, :tmp, :images, :cache].each do |dir|
      FileUtils.mkdir_p(@output[dir])
    end

    @engine = Engine.new(self)
  end

  attr_reader :app
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
  attr_reader :site_template
  attr_reader :page_template

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

  def img(name, alt: nil, id: nil, klass: nil)
    alt   = %Q( alt="#{alt}")     if alt
    id    = %Q( id="#{id}")       if id
    klass = %Q( class="#{klass}") if klass

    link = @output[:images].relative_path_from(@output[:render]) + name
    link = "/#{link}"

    return %Q(<img#{id}#{klass}#{alt} src="#{link}" />)
  end

  def link_styles
    @styles.map {|n,s| s.head_link }.join("\n")
  end

  def link_google_fonts()
    if @conf[:google_fonts]
      fonts = @conf[:google_fonts].join('|')
      url = "https://fonts.googleapis.com/css?family=#{fonts}"
      return %Q(<link href="#{url}" rel="stylesheet" type="text/css" />)
    end
  end

  def link_favicons
    if !@favicon.nil?
      links = []
      @favicon.formats.each do |format|
        unless format.format == 'ico'
          links << %Q(<link rel="icon" type="image/#{format.format}" sizes="#{format.resolution}" href="#{format.path.link}">)
        end
      end
      return links.join("\n")
    end
  end

  def insert_analytics
    if @conf[:analytics_key]
      return <<-JAVASCRIPT
      <script>
        (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
        (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
        m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
        })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

        ga('create', '#{@conf[:analytics_key]}', 'auto');
        ga('send', 'pageview');

      </script>
      JAVASCRIPT
    end
  end

  def meta(name, content)
    if name && content
      return %Q(<meta name="#{name}" content="#{content}" />)
    end
  end

  def inspect
    return "#<Site:#{@conf[:title]}>"
  end
end # class Site

end # module ARKWEB

