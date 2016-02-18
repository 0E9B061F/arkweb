module ARKWEB



class Engine

  class EngineError < RuntimeError
  end

  # Creates bindings for rendering ERB templates
  class Sandbox
    def initialize(env)
      env.each do |k,v|
        self.instance_variable_set("@#{k.to_s}", v)
      end
    end
    def bindings
      binding
    end
  end

  def initialize(site)
    @site = site

    if @site.conf.validate && ARKWEB.optional_gem('w3c_validators')
      @validator  = W3CValidators::MarkupValidator.new
    end

    if @site.conf.minify && ARKWEB.optional_gem('yui/compressor')
      @css_press  = YUI::CssCompressor.new
      @java_press = YUI::JavaScriptCompressor.new
    end

    if @site.templates.page
      @page_erb = @site.templates.page.read
    else
      @page_erb = false
    end
    @site_erb = @site.templates.site.read

    @cropped = {}
    @changed_sections = []
  end
  attr_reader :pages

  def self.evaluate_erb(data, filename=false, **env)
    box = Sandbox.new(env)
    begin
      erb = ERB.new(data)
      erb.result(box.bindings)
    rescue => e
      if filename
        wrn "Error evaluating ERB in file '#{filename}'"
      end
      raise e
    end
  end

  def self.evaluate_md(data, filename=false)
    return unless ARKWEB.optional_gem('rdiscount')
    begin
      RDiscount.new(data).to_html
    rescue => e
      if filename
        wrn "Error evaluating markdown in file '#{filename}'"
      end
      raise e
    end
  end

  def self.evaluate_wiki(data, filename=false)
    return unless ARKWEB.optional_gem('wikicloth')
    begin
      WikiCloth::Parser.new(:data => data).to_html
    rescue => e
      if filename
        wrn "Error evaluating Wiki markup in file '#{filename}'"
      end
      raise e
    end
  end

  def self.render_page_contents(page, index=nil, collection=nil)
    site = page.site
    helper = Helper.new(site, page.section, page, collection, index)
    if page.has_erb?
      dbg "Evaluating ERB", 1
      markup = evaluate_erb(page.contents, page.path.input,
        site: site,
        section: page.section,
        page: page,
        helper: helper,
        index: index,
        collection: collection
      )
    else
      markup = page.contents
    end
    body = case page.type
    when 'md'
      dbg "Evaluating Markdown", 1
      evaluate_md(markup, page.path.input)
    when 'wiki'
      dbg "Evaluating MediaWiki markup", 1
      evaluate_wiki(markup, page.path.input)
    when 'html'
      markup
    else
      # XXX
      raise "Cannot render page type: #{page.type}"
    end
  end

  def self.render_page(page, index=nil, collection=nil)
    if index
      dbg "Rendering index #{index}", 1
    end
    site = page.site
    helper = Helper.new(site, page.section, page, collection, index)
    contents = render_page_contents(page, index, collection)
    if site.templates.page
      contents = evaluate_erb(site.templates.page_data, site.templates.page,
        site: site,
        section: page.section,
        page: page,
        helper: helper,
        body: contents
      )
    end
    return evaluate_erb(site.templates.site_data, site.templates.site,
      site: site,
      section: page.section,
      page: page,
      helper: helper,
      body: contents
    )
  end

  def copy_images
    unless @site.images.empty?
      FileUtils.mkdir_p(@site.output.images)
      dbg "Copying images: #{@site.input.images} -> #{@site.output.images}"
      @site.images.each do |image|
        FileUtils.cp_r(image.path.input, image.path.output)
      end
    end
    @site.pages.each do |page|
      page.images.each do |image|
        FileUtils.cp_r(image.path.input, image.path.output)
      end
    end
  end

  def copy_scripts
    @site.pages.each do |page|
      page.scripts.each do |script|
        FileUtils.cp_r(script.path.input, script.path.output)
      end
    end
  end

  def render_style(style)
    FileUtils.mkdir_p(style.path.output.dirname)
    if style.is_css?
      FileUtils.cp(style.path.input, style.path.output)
    else
      # Only render if output doesn't already exist, or if output is outdated
      if style.path.changed?
        dbg "Rendering SASS file '#{style}' to '#{style.path.output}'"
        `sass -t compressed #{style.path.input} #{style.path.output}`
      end
    end
  end

  def render_styles
    @site.styles.each do |style|
      self.render_style(style)
    end
    @site.pages.each do |page|
      page.styles.each do |style|
        self.render_style(style)
      end
    end
  end

  def write_pages
    @site.pages.each do |page|
      msg "Processing page: #{page.path.link}"

      # Make sure the appropriate subdirectories exist in the output folder
      FileUtils.mkdir_p(page.path.output.dirname)

      if page.paginate
        if page.path.changed? || page.collect.any? {|s| @changed_sections.member?(s) }
          pages = page.collect.map {|a| @site.section(a).members }.flatten
          collection = Collection.new(page, pages, page.paginate)
          collection.range.each do |index|
            data = Engine.render_page(page, index, collection)
            page.path.paginated_output(index).write(data)
            dbg "Wrote index #{index}", 1
          end
        else
          dbg "Unchanged", 1
        end
      else
        if page.path.changed?
          data = Engine.render_page(page)
          page.path.output.write(data)
          dbg "Wrote page", 1
        else
          dbg "Unchanged", 1
        end
      end
    end
  end

  def validate
    if @site.conf.validate && ARKWEB.optional_gem('w3c_validators')
      @site.pages.each do |page|
        result = @validator.validate_file(page.path.output)
        if result.errors.length > 0
          msg "#{page}: invalid!"
          result.errors.each {|e| dbg ARK::Text.wrap(e.to_s, indent: 15, indent_after: true), 1 }
        else
          msg "#{page}: valid!"
        end
      end
    end
  end

  def clobber
    if @site.conf.clobber
      dbg "Clobbering old output from: #{@site.output.root}"
      @site.output.root.rmtree if @site.output.root.exist?
    end
  end

  def clean(force: false)
    if @site.conf.clean || force
      dbg "Removing temporary files: #{@site.output.tmp}"
      @site.output.tmp.rmtree if @site.output.tmp.exist?
    end
  end

  def minify
    # XXX Don't forget to add javascript minification
    if @site.conf.minify && ARKWEB.optional_gem('yui/compressor')
      @site.styles.each do |name, style|
        begin
          dbg "Minifying stylesheet: #{style}"
          data = style.path.output.read
          pressed = @css_press.compress(data)
          style.path.output.write(pressed)
        rescue => e
          wrn "Failed to minify file: #{style}"
          wrn e, 1
        end
      end
    end
  end

  def copy_inclusions
    @site.sections.each do |s|
      s.conf(:include).each do |dest, target|
        tmp = s.path.output.join(dest)
        target = Pathname.new(target)
        unless target.exist?
          raise EngineError, "Error including target '#{target}': target doesn't exist."
        end
        dbg "Including #{target} at #{dest}"
        tmp.dirname.mkpath
        FileUtils.cp_r(target, tmp)
      end
    end
  end

  def run_hooks(hooks)
    hooks.each do |hook|
      basename = File.basename(hook)
      dbg "Running hook: #{basename}"
      output = `#{hook}`
      output.each_line do |line|
        dbg "$ #{line}", 1
      end
    end
  end

  def run_before_hooks
    self.run_hooks(@site.hooks.before)
  end

  def run_after_hooks
    self.run_hooks(@site.hooks.after)
  end

  def generate_favicons
    if @site.assets.favicon;w && ARKWEB.optional_gem('mini_magick')
      msg 'Generating favicons'
      FileUtils.mkdir_p(@site.output.favicons)
      @site.assets.favicon.formats.each do |format|
        if format.path.changed?
          dbg "#{format.path.output.basename}: generating.", 1
          img = MiniMagick::Image.open(format.path.input)
          img.resize(format.resolution)
          img.format(format.format)
          img.write(format.path.output)
          format.path.output.chmod(0644)
        else
          dbg "#{format.path.output.basename}: unchanged", 1
        end
      end
    end
  end

  def deploy
    if @site.conf.deploy
      unless @site.conf.remote
        raise EngineError, "Asked to deploy but no remote was given. Specify a remote location with `--remote`"
      end
      addr = URI(@site.conf.remote)
      msg "Deploying to #{addr}"
      host = "#{addr.host}:#{addr.path}"
      if addr.scheme == 'ssh'
        if addr.port
          port = "-p #{addr.port}"
        else
          port = ''
        end
        `rsync -az --delete-before -e "ssh #{port}" #{@site.output.root}/ #{host}`
      else
        `rsync -az --delete-before #{@site.output.root}/ #{host}`
      end
    end
  end

  def write_path_cache
    cache = YAML.dump(@site.path_cache._data)
    @site.output.pathcache.write(cache)
  end

  def analyze_output
    return unless @site.smart_rendering
    @site.pages.each do |page|
      if page.path.changed?
        @changed_sections << page.section.path.link
      end
    end
    @site.path_cache._each do |type,paths|
      leftovers = @site.old_cache[type] - paths
      @cropped[type] = leftovers
      @cropped[type].each do |path|
        if type == :pages
          sec_link = Pathname.new(File.dirname(path))
          root = Pathname.new('/')
          sec_link = root.join(sec_link)
          @changed_sections << @site.section(sec_link).path.link
        end
      end
    end
  end

  def crop_output
    return unless @site.smart_rendering
    @cropped.each do |type,paths|
      paths.each do |path|
        path = @site.output.root.join(path)
        if path.file?
          path.delete
        else
          path.rmtree
        end
      end
    end
  end

  def write_site
    self.clobber
    self.clean(force: true)
    self.analyze_output
    self.crop_output
    self.run_before_hooks
    self.write_pages
    self.generate_favicons
    self.render_styles
    self.copy_images
    self.copy_scripts
    self.copy_inclusions
    self.minify
    self.validate
    self.write_path_cache
    self.run_after_hooks
    self.deploy
    self.clean
  end

end # class Engine

end # module ARKWEB

