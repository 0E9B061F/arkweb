module ARKWEB


class Collection
  def initialize(page, pages, pagesize)
    @page      = page
    @pages     = pages
    @pagesize  = pagesize
    @pagecount = (@pages.length / @pagesize.to_f).ceil
    @range     = (1..@pagecount)
  end

  attr_reader :range
  attr_reader :pagecount

  def paginate(index)
    index = index - 1
    first = index * @pagesize
    last  = first + (@pagesize - 1)
    @pages[first..last]
  end

  def links(index)
    links = []
    @range.each do |i|
      if i == index
        links << "<span class=\"pagination pagination-current\">#{index}</span>"
      else
        links << @page.link_to(text: i, klass: 'pagination pagination-link', index: i)
      end
    end
    links.join("\n")
  end
end


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

  def initialize(site, mode='html5')
    @site = site
    @pages = {}
    @template = @site.interface.root("templates/#{mode}.html.erb")
    @cache = {}

    if @site.info(:validate) && ARKWEB.optional_gem('w3c_validators')
      @validator  = W3CValidators::MarkupValidator.new
    end

    if @site.info(:minify) && ARKWEB.optional_gem('yui/compressor')
      @css_press  = YUI::CssCompressor.new
      @java_press = YUI::JavaScriptCompressor.new
    end

    @page_erb = File.open(@site.in(:page_erb), 'r') {|f| f.read }
    @site_erb = if File.exist?(@site.in(:site_erb))
      File.open(@site.in(:site_erb), 'r') {|f| f.read }
    else
      File.open(@template, 'r') {|f| f.read }
    end
  end
  attr_reader :pages

  def read(file)
    @cache[file] ||= File.open(file, 'r') {|f| f.read }
  end

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
      dbg "#{page.base}: rendering index #{index}", 1
    end
    if page.has_erb?
      dbg "#{page.base}: evaluating ERB", 1
      markup = self.evaluate_erb(page.contents, :site => @site, :section => page.section, :page => page, :index => index, :collection => collection)
    else
      markup = page.contents
    end
    html = case page.type
    when 'md'
      dbg "#{page.base}: evaluating Markdown", 1
      self.evaluate_md(markup)
    when 'wiki'
      dbg "#{page.base}: evaluating MediaWiki markup", 1
      self.evaluate_wiki(markup)
    when 'html'
      markup
    else
      # XXX
      raise "Cannot render page type: #{page.type}"
    end
    body = self.evaluate_erb(@page_erb, :site => @site, :body => html, :section => page.section, :page => page)
    self.evaluate_erb(@site_erb, :site => @site, :body => body, :section => page.section, :page => page)
  end

  def copy_images
    unless @site.images.empty?
      FileUtils.mkdir_p(@site.out(:images))
      dbg "Copying images: #{@site.in(:images)} -> #{@site.out(:images)}"
      FileUtils.cp_r(@site.images, @site.out(:images))
    end
  end

  def render_styles
    FileUtils.mkdir_p(@site.out(:aw))
    @site.styles.each do |name, style|
      if style.is_css?
        FileUtils.cp(style.working_path, style.output_path)
      else
        # Only render if output doesn't already exist, or if output is outdated
        if !File.exist?(style.output_path) || File.mtime(style.working_path) > File.mtime(style.output_path)
          dbg "Rendering SASS file '#{style}' to '#{style.output_path}'"
          `sass -t compressed #{style.working_path} #{style.output_path}`
        end
      end
    end
  end

  def download_fontsquirrel
    # Get FontSquirrel fonts
    if !@site.info(:webfonts)['fontsquirrel'].empty? && ARKWEB.optional_gem('libarchive')
      @site.info(:webfonts)['fontsquirrel'].each do |font|
        url = "http://www.fontsquirrel.com/fonts/download/#{font}"
        FileUtils.mkdir_p(@site.out(:tmp))
        dest = File.join(@site.out(:tmp), "#{font}.zip")
        begin
          font_cache = File.join(@site.out(:cache), font)
          unless File.directory?(font_cache)
            FileUtils.mkdir_p(font_cache)

            dbg "Downloading Font Squirrel font: #{font}"

            open(url) do |src|                                   # XXX switch to a different HTTP client?
              File.open(dest, 'wb') {|f| f.write(src.read) }
            end

            dbg "Extracting and caching font: #{font}"

            Archive.read_open_filename(dest) do |zip|
              while entry = zip.next_header
                case entry.pathname
                when 'stylesheet.css'
                  File.open(File.join(font_cache, "#{font}.css"), 'w') do |f|
                    f.write(zip.read_data)
                  end
                when /\.(woff|ttf|eot|svg|otf)$/
                  File.open(File.join(font_cache, entry.pathname), 'w') do |f|
                    f.write(zip.read_data)
                  end
                end
              end
            end

          end
          FileUtils.mkdir_p(@site.out(:fonts))
          FileUtils.cp(Dir[File.join(font_cache, '*')], @site.out(:fonts))
        rescue => e
          wrn "Failed getting Font Squirrel font '#{font}'"
          wrn e, 1
        end
      end
    end
  end

  def write_page(page)
    msg "Processing page: #{page.base}"

    # Make sure the appropriate subdirectories exist in the output folder
    FileUtils.mkdir_p(page.out_dir)

    if !page.collect.empty? && page.pagesize
      pages = page.collect.map {|a| @site.sections[a].pages }.flatten.sort {|a,b| a <=> b }
      collection = Collection.new(page, pages, page.pagesize)
      r = 1..collection.pagecount
      r.each do |index|
        data = self.render_page(page, index, collection)
        File.open(page.paginated_out(index), 'w') {|f| f.write(data) }
        dbg "#{page.base}: wrote index #{index}", 1
      end
    else
      data = self.render_page(page)
      File.open(page.out, 'w') {|f| f.write(data) }
      dbg "#{page.base}: wrote page", 1
    end
  end

  def validate
    if @site.info(:validate) && ARKWEB.optional_gem('w3c_validators')
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
    if @site.info(:clobber)
      [:render, :cache, :tmp].each do |p|
        if File.directory?(@site.out(p))
          dbg "Clobbering directory: #{@site.out(p)}"
          FileUtils.rm_r(@site.out(p))
        end
      end
    end
  end

  def clean
    if @site.info(:clean)
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
    if @site.info(:minify) && ARKWEB.optional_gem('yui/compressor')
      @site.styles.each do |name, style|
        begin
          dbg "Minifying stylesheet: #{style}"
          data = File.open(style.output_path, 'r') {|f| f.read }
          pressed = @css_press.compress(data)
          File.open(style.output_path, 'w') {|f| f.write(pressed) }
        rescue => e
          wrn "Failed to minify file: #{style}"
          wrn e, 1
        end
      end
    end
  end

  def copy_inclusions
    @site.sections.each do |name, s|
      s.inclusions.each do |dest, target|
        dest = File.join(s.output_path, dest)
        dbg "Including #{target} at #{dest}"
        unless File.exist?(target)
          raise EngineError, "Error including target '#{target}': target doesn't exist."
        end
        if File.exist?(dest)
          FileUtils.rm_r(dest)
        end
        FileUtils.mkdir_p(File.dirname(dest))
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
      img = MiniMagick::Image.open(@site.favicon.input_path)
      @site.favicon.formats.each do |format|
        dbg "Generating favicon: #{format.name}", 1
        img.resize(format.resolution)
        img.format(format.format)
        img.write(format.output_path)
        File.chmod(0644, format.output_path)
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
    self.download_fontsquirrel
    self.copy_inclusions
    self.minify
    self.validate
    self.clean
    self.run_after_hooks
  end

end # class Engine


end # module ARKWEB

