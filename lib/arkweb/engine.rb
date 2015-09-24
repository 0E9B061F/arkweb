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

    if @site.conf(:validate) && ARKWEB.optional_gem('w3c_validators')
      @validator  = W3CValidators::MarkupValidator.new
    end

    if @site.conf(:minify) && ARKWEB.optional_gem('yui/compressor')
      @css_press  = YUI::CssCompressor.new
      @java_press = YUI::JavaScriptCompressor.new
    end

    if @site.page_template
      @page_erb = @site.page_template.read
    else
      @page_erb = false
    end
    @site_erb = @site.site_template.read

    @cropped = {}
    @changed_sections = []
  end
  attr_reader :pages

  def evaluate_erb(data, env)
    box = Sandbox.new(env)
    erb = ERB.new(data)
    erb.result(box.bindings)
  end

  def evaluate_md(data)
    return unless ARKWEB.optional_gem('rdiscount')
    RDiscount.new(data).to_html
  end

  def evaluate_wiki(data)
    return unless ARKWEB.optional_gem('wikicloth')
    WikiCloth::Parser.new(:data => data).to_html
  end

  def render_page(page, index=nil, collection=nil)
    if index
      dbg "Rendering index #{index}", 1
    end
    if page.has_erb?
      dbg "Evaluating ERB", 1
      markup = self.evaluate_erb(page.contents, :site => @site, :section => page.section, :page => page, :index => index, :collection => collection)
    else
      markup = page.contents
    end
    body = case page.type
    when 'md'
      dbg "Evaluating Markdown", 1
      self.evaluate_md(markup)
    when 'wiki'
      dbg "Evaluating MediaWiki markup", 1
      self.evaluate_wiki(markup)
    when 'html'
      markup
    else
      # XXX
      raise "Cannot render page type: #{page.type}"
    end
    if @page_erb
      body = self.evaluate_erb(@page_erb,
        :site => @site,
        :body => body,
        :section => page.section,
        :page => page
      )
    end
    return self.evaluate_erb(@site_erb,
      :site => @site,
      :body => body,
      :section => page.section,
      :page => page
    )
  end

  def copy_images
    unless @site.images.empty?
      FileUtils.mkdir_p(@site.out(:images))
      dbg "Copying images: #{@site.in(:images)} -> #{@site.out(:images)}"
      FileUtils.cp_r(@site.images, @site.out(:images))
    end
  end

  def render_styles
    @site.styles.each do |name, style|
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
  end

  def write_pages
    @site.pages.each do |page|
      msg "Processing page: #{page.path.basename}"

      # Make sure the appropriate subdirectories exist in the output folder
      FileUtils.mkdir_p(page.path.output.dirname)

      if !page.collect.empty? && page.pagesize
        if page.path.changed? || page.collect.any? {|s| @changed_sections.member?(s) }
          pages = page.collect.map {|a| @site.section(a).pages }.flatten.sort {|a,b| a <=> b }
          collection = Collection.new(page, pages, page.pagesize)
          collection.range.each do |index|
            data = self.render_page(page, index, collection)
            page.path.paginated_output(index).write(data)
            dbg "Wrote index #{index}", 1
          end
        else
          dbg "Unchanged", 1
        end
      else
        if page.path.changed?
          data = self.render_page(page)
          page.path.output.write(data)
          dbg "Wrote page", 1
        else
          dbg "Unchanged", 1
        end
      end
    end
  end

  def validate
    if @site.conf(:validate) && ARKWEB.optional_gem('w3c_validators')
      @site.pages.each do |page|
        result = @validator.validate_file(page.path.output)
        if result.errors.length > 0
          msg "#{page}: invalid!"
          result.errors.each {|e| dbg Ark::Text.wrap(e.to_s, indent: 15, indent_after: true), 1 }
        else
          msg "#{page}: valid!"
        end
      end
    end
  end

  def clobber
    if @site.conf(:clobber)
      dbg "Clobbering old output from: #{@site.out(:root)}"
      @site.out(:root).rmtree if @site.out(:root).exist?
    end
  end

  def clean(force: false)
    if @site.conf(:clean) || force
      dbg "Removing temporary files: #{@site.out(:tmp)}"
      @site.out(:tmp).rmtree if @site.out(:tmp).exist?
    end
  end

  def minify
    # XXX Don't forget to add javascript minification
    if @site.conf(:minify) && ARKWEB.optional_gem('yui/compressor')
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
      s.inclusions.each do |dest, target|
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

  def run_before_hooks
    @site.before_hooks.each do |hook|
      basename = File.basename(hook)
      dbg "Running hook: #{basename}"
      output = `#{hook}`
      output.split("\n").map {|line| "#{basename}: #{line}" }.each do |line|
        dbg line, 1
      end
    end
  end

  def run_after_hooks
    @site.after_hooks.each do |hook|
      basename = File.basename(hook)
      dbg "Running hook: #{basename}"
      output = `#{hook}`
      output.split("\n").map {|line| "#{basename}: #{line}" }.each do |line|
        dbg line, 1
      end
    end
  end

  def generate_favicons
    if !@site.favicon.nil? && ARKWEB.optional_gem('mini_magick')
      msg 'Generating favicons'
      FileUtils.mkdir_p(@site.out(:favicons))
      @site.favicon.formats.each do |format|
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
    addr = @site.conf(:deploy)
    if addr
      msg "Deploying to #{addr['host']}"
      if addr['ssh']
        if addr['port']
          port = "-p #{addr['port']}"
        else
          port = ''
        end
        `rsync -az --delete-before -e "ssh #{port}" #{@site.out(:root)}/ #{addr['host']}`
      else
        `rsync -az --delete-before #{@site.out(:root)}/ #{addr['host']}`
      end
    end
  end

  def write_path_cache
    cache = YAML.dump(@site.path_cache)
    @site.path_cache_file.write(cache)
  end

  def analyze_output
    return unless @site.smart_rendering
    @site.pages.each do |page|
      if page.path.changed?
        @changed_sections << page.section.path.address
      end
    end
    @site.path_cache.each do |type,paths|
      leftovers = @site.old_path_cache[type] - paths
      @cropped[type] = leftovers
      @cropped[type].each do |path|
        if type == :pages
          sec_address = File.dirname(path)
          sec_address = Site::RootSectionName if sec_address == '.'
          @changed_sections << @site.section(sec_address).path.address
        end
      end
    end
  end

  def crop_output
    return unless @site.smart_rendering
    @cropped.each do |type,paths|
      paths.each do |path|
        path = @site.out(:root).join(path)
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

