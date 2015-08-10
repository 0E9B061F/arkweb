module ARKWEB

class Section
	def initialize(site, path)
		@site = site
		@path = path
		@pages = Dir[File.join(@path, Site::Types[:pages])].map {|path| Page.new(@site, path, self)}
		@title = File.basename(@path).capitalize()
	end
	attr_reader :site, :path, :pages, :title

	def page_count()
		return @pages.length()
	end
end

class Page
	def initialize(site, path, section)
		@site = site
		@path = path
		@relative = Pathname.new(@path).relative_path_from(Pathname.new(@site.root))
		@relativedir = File.dirname(@relative)
		@section = section
    @base = File.basename(@path)
    @name = @base[/(.+)\..+?\.page$/, 1]
		@title = @name.tr('-', ' ').split(/(\W)/).map(&:capitalize).join
		@html = "#{@name}.html"
		@link = File.join(@relativedir, @html)
    @out  = File.join(@site[:output], @link)
		@out_dir = File.dirname(@out)
    @type = @path[/\.(.+)\.page$/, 1]
	end
	attr_reader :site, :path, :section
	attr_reader :base, :name, :out, :type
	attr_reader :out_dir, :title, :relativedir
	attr_reader :link

	def link_to(**options)
		text  = options[:text]  || @title
		id    = options[:id]    || nil
		klass = options[:class] || nil
		id    = %Q( id="#{id}")       if id
		klass = %Q( class="#{klass}") if klass
		return %Q(<a#{id}#{klass} href="#{@link}">#{text}</a>)
	end

	def to_s()
		return @path
	end
end

class Site

  Paths = {}
	Paths[:arkweb]   = "ARKWEB"
	Paths[:header]   = File.join(Paths[:arkweb], "header.yaml")
	Paths[:page_erb] = File.join(Paths[:arkweb], "page.html.erb")
	Paths[:site_erb] = File.join(Paths[:arkweb], "site.html.erb")
	Paths[:output]   = File.join(Paths[:arkweb], "html")
	Paths[:tmp]      = File.join(Paths[:arkweb], "tmp")
	Paths[:cache]    = File.join(Paths[:arkweb], "cache")
	Paths[:images]   = "img"

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
      fonts.map {|font| "#{font}.css" }
    }
  }
  
  def initialize(root)
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

    @paths[:output] = Conf[:output] || header['output'] || @paths[:output]
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
    @styles    = header['styles']

    if @webfonts
      if @webfonts['fontsquirrel']
        @webfonts['fontsquirrel'].map! {|f| f.tr(' ', '-') }
      end
      urls = []
      @webfonts.each do |service,fonts|
        service = service.to_sym
        if FontService[service]
          urls += FontService[service][fonts]
        else
          wrn "Unknown font provider '#{service}' for fonts: #{fonts}"
        end
      end
      @styles += urls
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
			@sections[path] = s
			@pages += s.pages
		end

    [:output, :tmp, :images, :cache].each do |dir|
      FileUtils.mkdir_p(@paths[dir])
    end

    @engine = Engine.new(self)
  end
  attr_reader :root, :name, :paths
  attr_reader :author, :title, :desc, :tags, :keywords, :xuacompat
  attr_reader :webfonts, :styles, :files, :engine
	attr_reader :pages, :sections

  private

  # Create site-relative paths from Paths
  def make_path
    path = {}
    Paths.each do |name, p|
      path[name] = File.join(@root, p)
    end
    return path
  end

  public

  # Convenience method for accessing #paths
  def [](key)
    @paths[key]
  end

end # class Site
end # module ARKWEB

