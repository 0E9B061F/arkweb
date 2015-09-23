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
      dbg "#{page.path.basename}: rendering index #{index}", 1
    end
    if page.has_erb?
      dbg "#{page.path.basename}: evaluating ERB", 1
      markup = self.evaluate_erb(page.contents, :site => @site, :section => page.section, :page => page, :index => index, :collection => collection)
    else
      markup = page.contents
    end
    body = case page.type
    when 'md'
      dbg "#{page.path.basename}: evaluating Markdown", 1
      self.evaluate_md(markup)
    when 'wiki'
      dbg "#{page.path.basename}: evaluating MediaWiki markup", 1
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
    self.evaluate_erb(@site_erb,
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

  def write_page(page)
    msg "Processing page: #{page.path.basename}"

    # Make sure the appropriate subdirectories exist in the output folder
    FileUtils.mkdir_p(page.path.output.dirname)

    if page.path.changed?
      if !page.collect.empty? && page.pagesize
        pages = page.collect.map {|a| @site.section(a).pages }.flatten.sort {|a,b| a <=> b }
        collection = Collection.new(page, pages, page.pagesize)
        r = 1..collection.pagecount
        r.each do |index|
          data = self.render_page(page, index, collection)
          page.path.paginated_output(index).write(data)
          dbg "#{page.path.basename}: wrote index #{index}", 1
        end
      else
        data = self.render_page(page)
        page.path.output.write(data)
        dbg "#{page.path.basename}: wrote page", 1
      end
    else
      dbg "#{page.path.basename}: unchanged, skipping.", 1
    end
  end

  def validate
    if @site.conf(:validate) && ARKWEB.optional_gem('w3c_validators')
      @site.pages.each do |page|
        result = @validator.validate_file(page.out)
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
      [:render, :cache, :tmp].each do |p|
        if File.directory?(@site.out(p))
          dbg "Clobbering directory: #{@site.out(p)}"
          FileUtils.rm_r(@site.out(p))
        end
      end
    end
  end

  def clean
    if @site.conf(:clean)
      [:cache, :tmp].each do |p|
        if File.directory?(@site.out(p))
          dbg "Cleaning directory: #{@site.out(p)}"
          FileUtils.rm_r(@site.out(p))
        end
      end
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
        dest = s.path.output.join(dest)
        target = Pathname.new(target)
        dbg "Including #{target} at #{dest}"
        unless target.exist?
          raise EngineError, "Error including target '#{target}': target doesn't exist."
        end
        dest.rmtree if dest.exist?
        dest.dirname.mkpath
        FileUtils.cp_r(target, dest)
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
          dbg "#{format.path.output.basename}: unchanged, skipping.", 1
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
        `rsync -az --delete-before -e "ssh #{port}" #{@site.out(:render)}/ #{addr['host']}`
      else
        `rsync -az --delete-before #{@site.out(:render)}/ #{addr['host']}`
      end
    end
  end

  def write_site
    self.run_before_hooks
    self.clobber

    @site.pages.each do |page|
      self.write_page(page)
    end

    self.generate_favicons
    self.render_styles
    self.copy_images
    self.copy_inclusions
    self.minify
    self.validate
    self.run_after_hooks
    self.deploy
    self.clean
  end

end # class Engine


end # module ARKWEB

