module ARKWEB

class Section
	def initialize(site, path)
		@site = site
		@path = path

		# Get all pages in this section
		page_glob = File.join(@path, Site::Types[:pages])
		@pages = Dir[page_glob].map do |path|
			Page.new(@site, path, self)
		end

		# Order pages by ctime and give them an index
		@ordered_pages = @pages.sort {|a,b| a.ctime <=> b.ctime }
		@ordered_pages.each_with_index do |page,i|
			page.index = i + 1
		end

		# Get a title for this section
		@title = File.basename(@path).capitalize()

		# Path-related stuff
		@relative = Pathname.new(@path).relative_path_from(Pathname.new(@site.root))
	end
	attr_reader :site, :path, :pages, :title, :ordered_pages

	def page_count()
		return @pages.length()
	end

	def link_to(**options)
		text  = options[:text]  || @title
		id    = options[:id]    || nil
		klass = options[:class] || nil
		id    = %Q( id="#{id}")       if id
		klass = %Q( class="#{klass}") if klass
		return %Q(<a#{id}#{klass} href="#{@relative}">#{text}</a>)
	end
end

class Page
	def initialize(site, path, section)
		@site = site
		@section = section

		@path = path

		@index = 0

		@atime = File.atime(@path)
		@ctime = File.ctime(@path)
		@mtime = File.mtime(@path)

		@text = File.open(@path, 'r') {|f| f.read }
		if (md = @text.match(/^(?<metadata>---\s*\n.*?\n?)^(---\s*$\n?)/m))
			@contents = md.post_match
			@metadata = YAML.load(md[:metadata])
			@has_metadata = true
		else
			@contents = @text
			@metadata = {}
			@has_metadata = false
		end

    @base  = File.basename(@path)
    @name  = @base[/(.+)\..+?\.page$/, 1]
		@title = @metadata['title'] || @name.tr('-', ' ').split(/(\W)/).map(&:capitalize).join
		@tags  = @metadata['keywords'] || @metadata['tags'] || []

		@relative = Pathname.new(@path).relative_path_from(Pathname.new(@site.root))
		@relativedir = File.dirname(@relative)

		@html = "#{@name}.html"

		@link = File.join('/', @relativedir, @html)

    @out  = File.join(@site[:output], @link)
		@out_dir = File.dirname(@out)

    @type = @path[/\.(.+)\.page$/, 1]
	end
	attr_reader :site, :path, :section
	attr_reader :base, :name, :out, :type
	attr_reader :out_dir, :title, :relativedir
	attr_reader :link
	attr_reader :contents, :has_metadata, :metadata
	attr_reader :atime, :ctime, :mtime
	attr_accessor :index

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
			@output_path  = File.join(@site[:aw_out], @rendered_name)
			@aw_path      = Pathname.new(@output_path).relative_path_from(Pathname.new(@site[:output])).to_s
			@server_path  = File.join('/', @aw_path)
		else
			site_dirname  = File.dirname(@site_path)
			rendered_path = File.join(site_dirname, @rendered_name)
			@output_path  = File.join(@site[:output], rendered_path)
			@server_path  = File.join('/', rendered_path)
		end
	end

	# True if this stylesheet is found in the ARKWEB directory. False if located
	# in the site structure.
	def site_style?
		return @section.nil?
	end

	# Return true if this stylesheet is in SASS
	def is_sass?
		return !@basename[/\.s[ca]ss$/].nil?
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

		# XXX
		@metadata = header

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
  attr_reader :root, :name, :paths
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

