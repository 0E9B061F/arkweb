# === ARKWEB-3 === #

require 'fileutils'
require 'yaml'
require 'erb'

require 'maruku'
require 'wikicloth'
require 'trollop'

module ARKWEB



# Utility functions and classes
module Util

  # Timer.time reports the time since the last call to Timer.reset
  class Timer
    def self.reset
      @@start = Time.now
    end
    def self.time
      t = Time.now - @@start
      "#{t.round(2)}"
    end
    reset
  end

  # Write to standard output according to a standard format and verbosity
  # options
  def say(msg, sym='...', loud=false)
    return false if Conf[:quiet]
    return false if loud && !Conf[:verbose]
    unless msg == ''
      time = Timer.time.to_s.ljust(4, '0')
      puts "#{time} #{sym} #{msg}"
    else
      puts
    end
  end
  def msg(str)
    say(str, '>>>', false)
  end
  def dbg(str)
    say(str, '...', true)
  end
  def wrn(str)
    say(str, '???', true)
  end

  def root(*args)
    File.join(Root, *args)
  end
end



class BrokenSiteError < StandardError
end



Root = File.absolute_path(File.join(File.dirname(__FILE__), '..'))

Project = YAML.load_file(File.join(Root, 'project.yaml'))
Pr = Project
Version = "#{Pr['name']} v#{Pr['version']} codename '#{Pr['codename']}'"

Usage = <<-BANNER
>>> #{Version}
    Copyright 2012 nn <nn@studio25.org>
#{Pr['name']} is a simple document processor for rendering flat websites.
USAGE: ark [options] SITEPATH
BANNER



Conf = Trollop.options do
  version Version
  banner Usage
  opt :output, "Directory to write output to",
    :short => :o, 
    :default => nil,
    :type => :string
  opt :verbose, "Toggle verbosity",
    :short => :v
  opt :quiet, "Run silently",
    :short => :q
# TODO
#  opt :plugin, "A comma-seperated list of plugins to load",
#    :short => :p,
#    :default => nil
end


# TODO
#class Plugin
#end



class Site

  Path = {
    :header   => "header.yaml",
    :pages    => "*.page",
    :page_erb => "page.html.erb",
    :site_erb => "site.html.erb",
    :output   => "html",
    :sass     => "*.{scss,sass}",
    :css      => "*.css",
    :images   => "img"
  }

  Webfont = "http://fonts.googleapis.com/css?family="

  def initialize(root)
    @root = root
    raise unless File.directory?(@root)
    @name = File.basename(@root)
    @path = self.make_path
    FileUtils.mkdir_p(@path[:output])

    @header = self.load_header
    @author = @header['author']
    @title  = @header['title']
    @desc   = @header['desc'] || @header['description']
    @tags   = @header['tags'] || @header['keywords']
    @keywords = @tags ? @tags.join(', ') : ''

    @styles = @header['styles']
    if @header['webfonts']
      webfonts = Webfont + @header['webfonts'].join('|')
      @styles << webfonts
    end

    @files = {}
    @files[:pages]  = Dir[@path[:pages]]
    @files[:images] = Dir[@path[:images]]
    @files[:css]    = Dir[@path[:css]]
    @files[:sass]   = Dir[@path[:sass]]
  end
  attr_reader :root, :path, :title, :desc, :tags, :keywords, :author, :header
  attr_reader :body, :styles, :files, :name
  alias description desc

  def site_template
    @path[:site_erb]
  end
  def page_template
    @path[:page_erb]
  end

  def make_path
    path = {}
    Path.each do |name, p|
      path[name] = File.join(@root, p)
    end
    return path
  end

  def load_header
    begin
      YAML.load_file(self.path[:header])
    rescue
      raise BrokenSiteError,
      "While loading site '#{self.root}': header file '#{@path[:header]}' is missing or malformed."
    end
  end

  def rel(path)
    path[/^.*(#{@name}.*)$/, 1] || path
  end

end



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



class Engine

  def initialize(site, mode='html5')
    @site = site
    @output = Conf[:output] || @site.path[:output]
    FileUtils.mkdir_p(@output)
    @page = ''
    @body = ''
    @pages = {}
    @template = root("templates/#{mode}.html.erb")
    @cache = {}
  end
  attr_reader :pages, :output

  def read(file)
    @cache[file] ||= File.open(file, 'r') {|f| f.read }
  end

  def evaluate_erb(file, env)
    dbg "Evaluating ERB file: #{@site.rel(file)}"
    data = self.read(file)
    box = Sandbox.new(env)
    erb = ERB.new(data)
    erb.result(box.bindings)
  end

  def evaluate_md(file)
    dbg "Evaluating Markdown file: #{@site.rel(file)}"
    data = self.read(file)
    doc = Maruku.new(data)
    doc.to_html
  end

  def evaluate_wiki(file)
    dbg "Evaluating MediaWiki markup file: #{@site.rel(file)}"
    data = self.read(file)
    doc = WikiCloth::Parser.new(:data => data)
    doc.to_html
  end

  def render_page(page)
    dbg "Rendering page: #{@site.rel(page)}"
    type  = page[/\.(.+)\.page$/, 1]
    @page = case type
    when 'md'
      self.evaluate_md(page)
    when 'erb'
      self.evaluate_erb(page, :site => @site)
    else
      self.read(page)
    end
    @body = self.evaluate_erb(@site.page_template, :site => @site, :page => @page)
    @page = ''
    @pages[page] = if File.exist?(@site.site_template)
      self.evaluate_erb(@site.site_template, :site => @site, :body => @body)
    else
      self.evaluate_erb(@template, :site => @site, :body => @body)
    end
    @body = ''
  end

  def copy_resources
    unless @site.files[:images].empty?
      dbg "Copying image directory: #{@site.rel(@site.path[:images])} -> #{@site.rel(@output)}"
      FileUtils.cp_r(@site.path[:images], @output)
    end

    unless @site.files[:css].empty?
      dbg "Copying style sheets: #{@site.css.join(', ')} -> #{@site.rel(@output)}"
      FileUtils.cp_r(@site.css, @output)
    end

    # Run sass over sass files
    @site.files[:sass].each do |sass|
      css = File.basename(sass).sub(/\.[^\.]+$/, '.css')
      css = File.join(@output, css)

      # Only render if output doesn't already exist, or if output is outdated
      if !File.exist?(css) || File.mtime(sass) > File.mtime(css)
        dbg "Rendering SASS file '#{@site.rel(sass)}' to '#{@site.rel(css)}'"
        `sass -t compressed #{sass} #{css}`
      end
    end
  end

  def write_page(page)
    msg "Writing page: #{@site.rel(page)}"
    base = File.basename(page)
    name = base[/(.+)\..+?\.page$/, 1]
    out = File.join(@output, "#{name}.html")
    self.render_page(page) unless @pages[page]
    File.open(out, 'w') {|f| f.write(@pages[page]) }
  end

  def write_site
    # self.run_before_hook
    @site.files[:pages].each do |page|
      self.write_page(page)
    end
    self.copy_resources
    # self.run_after_hook
  end

end



class Interface

# TODO
#  def self.load_plugins
#    if Conf[:plugin]
#      plugins = Conf[:plugin].split(',')
#      plugins.each do |plugin|
#        name = File.basename(plugin).sub(/\.[^\.]+?$/,'').capitalize
#        load plugin
#        klass = eval "ARKWEB::#{name}"
#        ARKWEB.register_plugin(klass)
#      end
#    end
#  end

  def self.run
    msg Version
    path = ARGV[0]
    if path
      msg "Processing site: #{path}"
      site = Site.new(path)
      eng  = Engine.new(site)
      eng.write_site
      msg "Done! Wrote site to: #{eng.output}"
    else
      wrn "Please supply a path to a site directory"
    end
  end

end



end # module ARKWEB



AW = ARKWEB
include AW::Util

