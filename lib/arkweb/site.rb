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

  def initialize(interface, root, conf=nil)

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
      :output => File.join(@input[:arkweb], 'output'),
      :tmp => File.join(@input[:arkweb], 'tmp'),
      :cache => File.join(@input[:arkweb], 'cache'),
    }
    opts = Hash[conf.opts.map {|k,v| [k.to_sym, v] }]
    @conf = defaults.merge(opts) {|k,old,new| new && !new.to_s.empty? ? new : old }
    @conf = @conf.merge(header) {|k,old,new| new && !new.to_s.empty? ? new : old }
    @conf.select! {|k,v| defaults.keys.member?(k) }

    # Finish with input paths
    @input[:styles] = header['styles'] || Dir[File.join(@input[:arkweb], Types[:style])]

    # Paths to where output files should be rendered
    @output = {}
    @output[:tmp]      = @conf[:tmp]
    @output[:cache]    = @conf[:cache]
    @output[:render]   = @conf[:output]
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

end # class Site
end # module ARKWEB

