# === ARKWEB-3 === #

require 'fileutils'
require 'yaml'
require 'erb'

require 'maruku'
require 'wikicloth'
require 'trollop'


def msg(*args)
  time = AW::Timer.time.to_s.ljust(5, '0')
  puts "#{time} | #{args.join(' ')}"
end
def root(*args)
  File.join(AW::Root, *args)
end


module ARKWEB

Root    = File.absolute_path(File.join(File.dirname(__FILE__), '..'))
Project = YAML.load_file(File.join(Root, 'project.yaml'))
Version = "#{Project['name']} v#{Project['version']} codename '#{Project['codename']}'"
Usage   = <<-BANNER
>>> #{Version}
    Copyright 2012 nn <nn@studio25.org>
#{Project['name']} is a simple document processor for rendering flat websites.
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
  opt :plugin, "A comma-seperated list of plugins to load",
    :short => :p,
    :default => nil
end

class Plugin
end

class Timer
  def self.reset
    @@start = Time.now
  end
  def self.time
    t = Time.now - @@start
    "#{t.round(3)}"
  end
  reset
end

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
    @path = self.make_path
    FileUtils.mkdir_p(@path[:output])

    @header = self.load_header
    @title       = @header['title']
    @description = @header['description']
    @keywords    = @header['keywords'].join(', ')
    @author      = @header['author']

    @styles = @header['styles']
    webfonts = Webfont + @header['webfonts'].join('|')
    @styles << webfonts

    @files = {}
    @files[:pages]  = Dir[@path[:pages]]
    @files[:images] = Dir[@path[:images]]
    @files[:css]    = Dir[@path[:css]]
    @files[:sass]   = Dir[@path[:sass]]
  end
  attr_reader :root, :path, :title, :description, :keywords, :author, :header
  attr_reader :body, :styles, :files

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
    YAML.load_file(self.path[:header])
  end

  def to_s
    <<-DISPLAY
    Site: #{self.title}
    Desc.: #{self.description}
    Keywords: #{self.keywords}
    Author: #{self.author}
    Styles: #{self.styles}
    DISPLAY
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

  def read(file)
    @cache[file] ||= File.open(file, 'r') {|f| f.read }
  end

  def evaluate_erb(file, env)
    msg "Evaluating ERB file '#{file}' ..."
    data = self.read(file)
    box = Sandbox.new(env)
    erb = ERB.new(data)
    erb.result(box.bindings)
  end

  def evaluate_md(file)
    msg "Evaluating Markdown file '#{file}' ..."
    data = self.read(file)
    doc = Maruku.new(data)
    doc.to_html
  end

  def evaluate_wiki(file)
    msg "Evaluating MediaWiki markup file '#{file}' ..."
    data = self.read(file)
    doc = WikiCloth::Parser.new(:data => data)
    doc.to_html
  end

  def render_page(page)
    msg "Rendering page #{page} ..."
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
      msg "Copying image directory: #{@site.path[:images]} -> #{@output}"
      FileUtils.cp_r(@site.path[:images], @output)
    end

    unless @site.files[:css].empty?
      msg "Copying style sheets: #{@site.css.join(', ')} -> #{@output}"
      FileUtils.cp_r(@site.css, @output)
    end

    # Run sass over sass files
    @site.files[:sass].each do |sass|
      css = File.basename(sass).sub(/\.[^\.]+$/, '.css')
      css = File.join(@output, css)

      # Only render if output doesn't already exist, or if output is outdated
      if !File.exist?(css) || File.mtime(sass) > File.mtime(css)
        msg "Rendering SASS file '#{sass}' to '#{css}'"
        `sass -t compressed #{sass} #{css}`
      end
    end
  end

  def write_page(page)
    msg "Writing page #{page} ..."
    base = File.basename(page)
    name = base[/(.+)\..+?\.page$/, 1]
    out = File.join(@output, "#{name}.html")
    self.render_page(page) unless @pages[page]
    File.open(out, 'w') {|f| f.write(@pages[page]) }
    puts
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
  def self.run
    if ARGV[0]
      if Conf[:plugin]
        plugins = Conf[:plugin].split(',')
        plugins.each do |plugin|
          name = File.basename(plugin).sub(/\.[^\.]+?$/,'').capitalize
          load plugin
          klass = eval "ARKWEB::#{name}"
          ARKWEB.register_plugin(klass)
        end
      end
      site = AW::Site.new(ARGV[0])
      eng  = AW::Engine.new(site)

      eng.write_site
      msg "Done!"
    else
      msg "Please supply a path to a site directory"
    end
  end
end

end # module ARKWEB

AW = ARKWEB

