module ARKWEB
class Engine

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
    @page = ''
    @body = ''
    @pages = {}
    @template = @site.interface.root("templates/#{mode}.html.erb")
    @cache = {}

    if Conf[:validate] && ARKWEB.optional_gem('w3c_validators')
      @validator  = W3CValidators::MarkupValidator.new
    end
    if Conf[:minify] && ARKWEB.optional_gem('yui/compressor')
      @css_press  = YUI::CssCompressor.new
      @java_press = YUI::JavaScriptCompressor.new
    end

		@page_erb = File.open(@site[:page_erb], 'r') {|f| f.read }
    @site_erb = if File.exist?(@site[:site_erb])
			File.open(@site[:site_erb], 'r') {|f| f.read }
    else
			File.open(@template, 'r') {|f| f.read }
    end
  end
  attr_reader :pages

  def read(file)
    @cache[file] ||= File.open(file, 'r') {|f| f.read }
  end

	# XXX this is here to handle rendering templates for now, since the other
	# eval function are expecting page objects. should make a similar template
	# object which follows the same interface.
  def evaluate_erb_data(data, env)
    dbg "Evaluating ERB template [XXX]"
    box = Sandbox.new(env)
    erb = ERB.new(data)
    erb.result(box.bindings)
  end

  def evaluate_erb(page, env)
    dbg "Evaluating ERB page: #{page}"
    box = Sandbox.new(env)
    erb = ERB.new(page.contents)
    erb.result(box.bindings)
  end

  def evaluate_md(page)
    return unless ARKWEB.optional_gem('rdiscount')
    dbg "Evaluating Markdown page: #{page}"
    RDiscount.new(page.contents).to_html
  end

  def evaluate_wiki(page)
    return unless ARKWEB.optional_gem('wikicloth')
    dbg "Evaluating MediaWiki markup page: #{page}"
    WikiCloth::Parser.new(:data => page.contents).to_html
  end

  def render_page(page)
    dbg "Rendering page: #{page}"
    @page = case page.type
    when 'md'
      self.evaluate_md(page)
    when 'wiki'
      self.evaluate_wiki(page)
    when 'erb'
      self.evaluate_erb(page, :site => @site)
    else
      page.contents
    end
    @body = self.evaluate_erb_data(@page_erb, :site => @site, :page => @page)
    @page = ''
    @pages[page] = self.evaluate_erb_data(@site_erb, :site => @site, :body => @body)
    @body = ''
    return true
  end

  def copy_resources
		# Make sure the appropriate subdirectories exist in the output folder
    FileUtils.mkdir_p(@site[:aw_out])
    FileUtils.mkdir_p(@site[:img_out])

    unless @site.files[:images].empty?
      dbg "Copying image directory: #{@site[:images]} -> #{@site[:img_out]}"
      FileUtils.cp_r(@site[:images], @site[:aw_out])
    end

		@site.styles.each do |style|
			if style[/\.css$/]
				FileUtils.cp(style, @site[:aw_out])
			elsif style[/\.s[ca]ss$/]
	      css = File.basename(style).sub(/\.[^\.]+$/, '.css')
  	    css = File.join(@site[:aw_out], css)

	      # Only render if output doesn't already exist, or if output is outdated
	      if !File.exist?(css) || File.mtime(style) > File.mtime(css)
	        dbg "Rendering SASS file '#{style}' to '#{css}'"
	        `sass -t compressed #{style} #{css}`
	      end
			end
		end

    if !@site.webfonts.empty? && ARKWEB.optional_gem('libarchive')
      @site.webfonts['fontsquirrel'].each do |font|
        url = "http://www.fontsquirrel.com/fontfacekit/#{font}"
        dest = File.join(@site[:tmp], "#{font}.zip")
        begin
          font_cache = File.join(@site[:cache], font)
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
                when /.*\.(woff)|(ttf)|(eot)|(svg)$}/
                  File.open(File.join(font_cache, entry.pathname), 'w') do |f|
                    f.write(zip.read_data)
                  end
                end
              end
            end

          end
          FileUtils.cp(Dir[File.join(font_cache, '*')], @site[:output])
        rescue => e
          wrn "Failed getting Font Squirrel font '#{font}'\n          #{e}"
        end
      end
    end
  end

  def write_page(page)
    msg "Writing page: #{page}"

    unless @pages[page]
      if self.render_page(page)
				# Make sure the appropriate subdirectories exist in the output folder
      	FileUtils.mkdir_p(page.out_dir)
				# Write the HTML file
        File.open(page.out, 'w') {|f| f.write(@pages[page]) }
      end
    end

    if Conf[:validate] && ARKWEB.optional_gem('w3c_validators')
      result = @validator.validate_file(page.out)
      msg "Validating file: #{page.out}"
      if result.errors.length > 0
        result.errors.each {|e| msg e.to_s }
      else
        msg "Valid!"
      end
    end
  end

  def write_site
    # self.run_before_hook
    @site.pages.each do |page|
      self.write_page(page)
    end
    self.copy_resources

    if Conf[:minify] && ARKWEB.optional_gem('yui/compressor')
      Dir[File.join(@site[:output], '*.{css,js}')].each do |path|
        begin
          dbg "Minifying file: #{path}"
          data = File.open(path, 'r') {|f| f.read }
          out = case File.extname(path)
          when '.css'
            @css_press.compress(data)
          when '.js'
            @java_press.compress(data)
          end
          File.open(path, 'w') {|f| f.write(out) }
        rescue => e
          wrn "Failed to minify file: #{path}"
          wrn e
        end
      end
    end

    # self.run_after_hook
    FileUtils.rm_r(@site[:tmp])
  end

end # class Engine
end # module ARKWEB

