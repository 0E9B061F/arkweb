module ARKWEB

class Site

  RootSectionName = 'root'
  OutputARKWEB    = 'aw'

  Paths = {}
  Paths[:arkweb]   = "ARKWEB"
  Paths[:header]   = File.join(Paths[:arkweb], "header.yaml")
  Paths[:page_erb] = File.join(Paths[:arkweb], "page.html.erb")
  Paths[:site_erb] = File.join(Paths[:arkweb], "site.html.erb")
  Paths[:style]    = File.join(Paths[:arkweb], "site.{css,sass,scss}")
  Paths[:output]   = File.join(Paths[:arkweb], "output")
  Paths[:aw_out]   = File.join(Paths[:output], OutputARKWEB)
  Paths[:img_out]  = File.join(Paths[:aw_out], "images")
  Paths[:tmp]      = File.join(Paths[:arkweb], "tmp")
  Paths[:cache]    = File.join(Paths[:arkweb], "cache")
  Paths[:images]   = "images"

  Types = {
    :pages    => "*.page",
    :images   => "*.{jpg,jpeg,png,gif}",
    :sass     => "*.{scss,sass}",
    :css      => "*.css"
  }

  FontService = {
    :google => lambda {|fonts|
      url = 'http://fonts.googleapis.com/css?family='
      fonts = fonts.join('|')
      return [url + fonts]
    },
    :fontsquirrel => lambda {|fonts|
      fonts.map {|font| File.join('/', OutputARKWEB, "#{font}.css") }
    }
  }

  def initialize(interface, root)
    @interface = interface
    raise BrokenSiteError unless File.directory?(root)
    @root = root
    @name = File.basename(root)
    @paths = make_path

    begin
      header = YAML.load_file(@paths[:header])
    rescue => e
      raise BrokenSiteError,
      "While loading site '#{@root}': #{e}\nHeader file '#{@paths[:header]}' is missing or malformed."
    end

    # XXX
    @metadata = header

    @paths[:output] = @interface.conf.opt(:output) || header['output'] || @paths[:output]
    @paths[:tmp]    = header['tmp'] || @paths[:tmp]
    @paths[:images] = header['images'] || @paths[:images]

    @author    = header['author']
    @title     = header['title']
    @desc      = header['desc'] || header['description']
    @tags      = header['tags'] || header['keywords']
    @xuacompat = header['xuacompat'] || false
    @keywords  = @tags ? @tags.join(', ') : ''
    @webfonts  = {'google' => [], 'fontsquirrel' => []}
    @webfonts  = @webfonts.merge(header['webfonts']) if header['webfonts']
    @styles    = header['styles'] || []

    # Create paths to each style, relative to the ARKWEB directory
    @styles.map! do |s|
      File.join(@paths[:arkweb], File.basename(s))
    end
    @styles << Dir[@paths[:style]].first()
    @styles = @styles.compact.uniq

    @output_styles = @styles.map do |style|
      css = File.basename(style).sub(/\.[^\.]+$/, '.css')
      File.join(@paths[:aw_out], css)
    end

    @link_styles = @output_styles.map do |style|
      link = Pathname.new(@paths[:aw_out]).relative_path_from(Pathname.new(@paths[:output]))
      File.join('/', link, File.basename(style))
    end

    @font_styles = []

    if @webfonts
      if @webfonts['fontsquirrel']
        @webfonts['fontsquirrel'].map! {|f| f.tr(' ', '-') }
      end
      @webfonts.each do |service,fonts|
        service = service.to_sym
        if FontService[service]
          @font_styles += FontService[service][fonts]
        else
          wrn "Unknown font provider '#{service}' for fonts: #{fonts}"
        end
      end
    end

    @files = {}
    @files[:pages]  = Dir[File.join(@root, Types[:pages])]
    @files[:images] = Dir[File.join(@paths[:images], Types[:images])]
    @files[:css]    = Dir[File.join(@root, Types[:css])]
    @files[:sass]   = Dir[File.join(@root, Types[:sass])]

    # Return a list of sections, which are any subdirectories excluding special subdirectories
    # The root directory is itself a section
    # Each section will later be scanned for pages and media, and then rendered
    subdirs = Dir[File.join(@root, '**/')].reject do |path|
      path.start_with?(@paths[:arkweb], @paths[:images])
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

    [:output, :tmp, :images, :cache].each do |dir|
      FileUtils.mkdir_p(@paths[dir])
    end

    @engine = Engine.new(self)
  end
  attr_reader :interface, :root, :name, :paths
  attr_reader :author, :title, :desc, :tags, :keywords, :xuacompat
  attr_reader :webfonts, :styles, :files, :engine
  attr_reader :pages, :sections
  attr_reader :metadata

  private

  # Create site-relative paths from Paths
  def make_path
    path = {}
    Paths.each do |name, p|
      path[name] = File.join(@root, p)
    end
    return path
  end

  def stylesheet_links(paths)
    links = []
    paths.each do |path|
      links << %Q(<link href="#{path}" rel="stylesheet" type="text/css" />)
    end
    return links.join("\n")
  end

  public

  # Convenience method for accessing #paths
  def [](key)
    @paths[key]
  end

  def img(name, **options)
    alt   = options[:alt]
    id    = options[:id]
    klass = options[:class]
    alt   = %Q( alt="#{alt}")     if alt
    id    = %Q( id="#{id}")       if id
    klass = %Q( class="#{klass}") if klass

    link = Pathname.new(@paths[:img_out]).relative_path_from(Pathname.new(@paths[:output]))
    link = File.join('/', link, name)

    return %Q(<img#{id}#{klass}#{alt} src="#{link}" />)
  end

  def link_styles()
    stylesheet_links(@link_styles)
  end

  def link_webfonts()
    stylesheet_links(@font_styles)
  end

end # class Site
end # module ARKWEB

