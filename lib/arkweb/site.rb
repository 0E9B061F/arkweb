module ARKWEB

class Site
  include HasAssets
  include HasContent

  RootSectionName = 'root'
  InputARKWEB     = 'AW'
  OutputARKWEB    = 'AW'

  Types = ClosedStruct.new(
    pages:  "*.{erb,md,html,wiki}",
    images: "*.{jpg,jpeg,png,gif}",
    script: "*.js",
    style:  "*.{css,scss,sass}",
    sass:   "*.{scss,sass}",
    css:    "*.css",
    icon:   "icon.{png,gif,ico,jpg,jpeg}"
  )

  def initialize(root, cli_conf=nil)
    # Basics
    @root = Pathname.new(root)
    raise BrokenSiteError unless @root.directory?
    @name = @root.basename

    @cli_conf = cli_conf

    @app = Application.new

    init_input
    refresh

    # Convenience
    @title = @conf.title
    @desc = @conf.desc || ''
  end

  attr_reader :app
  attr_reader :root
  attr_reader :name
  attr_reader :title
  attr_reader :desc
  attr_reader :conf
  attr_reader :hooks
  attr_reader :input
  attr_reader :output
  attr_reader :assets
  attr_reader :templates
  attr_reader :path_cache
  attr_reader :old_cache
  attr_reader :smart_rendering

  def refresh
    init_conf
    init_output
    init_hooks
    init_templates
    init_assets(@input.aw)
    init_contents
    init_pathcache
  end

  private

  # Define paths to input files
  def init_input
    @input = ClosedStruct.new do |input|
      input.aw           = @root + InputARKWEB
      input.header       = input.aw.join('header.yaml')
      input.page_erb     = input.aw.join('page.html.erb')
      input.site_erb     = input.aw.join('site.html.erb')
      input.autoindex    = input.aw.join('autoindex.html.erb')
      input.style        = input.aw.join('site.{css,sass,scss}')
      input.images       = input.aw.join('images')
      input.scripts      = input.aw.join('scripts')
      input.hooks        = input.aw.join('hook')
      input.before_hooks = input.hooks.join('before')
      input.after_hooks  = input.hooks.join('after')
    end
  end

  # Configure the site
  def init_conf
    # Default configuration values
    @conf = ClosedStruct.new(
      title:         'Untitled',
      author:        false,
      desc:          false,
      keywords:      false,
      google_fonts:  false,
      xuacompat:     false,
      analytics_key: false,
      clean:         false,
      clobber:       false,
      minify:        false,
      validate:      false,
      deploy:        false,
      output:        false,
      tmp:           false,
      cache:         false,
      remote:        false
    )

    # Load the header
    begin
      header = YAML.load_file(@input.header)
    rescue => e
      raise BrokenSiteError,
      "While loading site '#{@root}': #{e}\nHeader file '#{@input.header}' is missing or malformed."
    end
    header = Hash[header.map {|k,v| [k.to_sym, v] }]

    # Merge configuration sources
    if @cli_conf
      cli_conf = Hash[@cli_conf.opts.map {|k,v| [k.to_sym, v] }]
      @conf._update!(cli_conf)
    end
    @conf._update!(header)

    # Adjust types
    @conf.tmp = Pathname.new(@conf.tmp) if @conf.tmp
    @conf.output = Pathname.new(@conf.output) if @conf.output
  end

  # Define output paths
  def init_output
    @output = ClosedStruct.new do |out|
      out.tmp       = @conf.tmp || @input.aw.join('tmp')
      out.root      = @conf.output || @input.aw.join('output')
      out.aw        = out.root.join(OutputARKWEB)
      out.images    = out.aw.join('images')
      out.scripts   = out.aw.join('scripts')
      out.favicons  = out.aw.join('favicons')
      out.pathcache = out.aw.join('.path-cache.yaml')
    end
  end

  # Get hooks
  def init_hooks
    @hooks = ClosedStruct.new do |hooks|
      hooks.before = []
      hooks.after = []
      if @input.before_hooks.exist?
        hooks.before = @input.before_hooks.children.select {|c| c.executable? }
      end
      if @input.after_hooks.exist?
        hooks.after = @input.after_hooks.children.select {|c| c.executable? }
      end
    end
  end

  # Get templates
  def init_templates
    @templates = ClosedStruct.new do |templates|
      if @input.site_erb.exist?
        templates.site = @input.site_erb
      else
        templates.site = @app.root('templates/site.html.erb')
      end

      if @input.page_erb.exist?
        templates.page = @input.page_erb
      else
        templates.page = false
      end

      if @input.autoindex.exist?
        templates.autoindex = @input.autoindex
      else
        templates.autoindex = @app.root('templates/autoindex.html.erb')
      end
    end
  end

  # Get sections and pages
  def init_contents
    # Return a list of sections, which are any subdirectories excluding special subdirectories
    # The root directory is itself a section
    # Each section will later be scanned for pages and media, and then rendered
    subdirs = []
    @root.find do |path|
      if path.directory?
        if path == @input.aw || path.basename.to_s[0] == '.' || path.basename.to_s[-5..-1] == '.page'
          Find.prune
        else
          subdirs << path
        end
      end
    end
    @sections = ClosedHash.new
    @pages = ClosedHash.new
    subdirs.each do |path|
      section = Section.new(self, path)
      @sections[section.path.link] = section
      section.pages.each do |page|
        @pages[page.path.link] = page
      end
    end
  end

  # Path cache
  def init_pathcache
    @path_cache = ClosedStruct.new(
      pages:       [],
      images:      [],
      favicons:    [],
      stylesheets: [],
      sections:    []
    )
    if @output.pathcache.exist?
      @smart_rendering = true
      @old_cache = ClosedStruct.new(**YAML.load_file(@output.pathcache))
    else
      @smart_rendering = false
      @old_cache = false
    end

    @path_cache.favicons += @assets.favicon.formats.map {|f| f.path.link }
    @path_cache.stylesheets += @assets.styles.values.map {|s| s.path.link }
    @path_cache.pages += @pages.values.map {|p| p.path.link }
    @path_cache.sections += @sections.values.map {|s| s.path.link }
  end



  public


  #
  # Inspection
  #

  # Return all configuration pairs
  def configs
    return @conf._data
  end

  # Get sections and pages by their link path
  def addr(path)
    path = Pathname.new(path) unless path.is_a?(Pathname)
    @pages.merge(@sections).get(path, iname: 'section or path', kname: 'address')
  end

  # Access site sections by name
  def section(key)
    key = Pathname.new(key) unless key.is_a?(Pathname)
    @sections.get(key, iname: 'section', kname: 'address')
  end

  # Return an array of all sections in the site
  def sections
    return @sections.values
  end

  # Access pages by name
  def page(key)
    key = Pathname.new(key) unless key.is_a?(Pathname)
    @pages.get(key, iname: 'page', kname: 'address')
  end

  # Return an array of all pages on the site
  def pages
    return @pages.values
  end


  #
  # Asset Helpers
  #

  def link_image(name, **args)
    img = self.image(name)
    HTML.link_image(img, **args)
  end


  #
  # Utility
  #

  def inspect
    return %Q(#<AW::Site:"#{@conf[:title]}">)
  end
end # class Site

end # module ARKWEB

