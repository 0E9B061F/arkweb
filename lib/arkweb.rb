### ARKWEB

require 'fileutils'
require 'yaml'
require 'erb'
require 'pathname'
require 'open-uri'

require 'trollop'

require_relative 'arkweb/utility'
require_relative 'arkweb/error'
require_relative 'arkweb/site'
require_relative 'arkweb/engine'
require_relative 'arkweb/interface'




include ARKWEB::Utility



module ARKWEB

  Gem = {}

  # Attempt to load an optional dependency
  def self.optional_gem(name)
    return Gem[name] unless Gem[name].nil?
    Gem[name] = begin
      require name
      dbg "Loaded optional dependency: #{name}"
      true
    rescue LoadError
      wrn "Unable to load optional gem '#{name}'; functionality provided by '#{name}' will be disabled."
      false
    end
  end


  Root = File.absolute_path(File.join(File.dirname(__FILE__), '..'))
  ProjectFile = File.join(Root, 'project.yaml')
  FreezeFile  = File.join(Root, 'freeze.yaml')

  Project = YAML.load_file( File.exist?(FreezeFile) ? FreezeFile : ProjectFile )
  Pr = Project
  Version = "#{Pr['name']} v#{Pr['version']} codename '#{Pr['codename']}'"

  Usage = <<-BANNER
  >>> #{Version}
      Copyright 2012 nn <nn@studio25.org>
  #{Pr['name']} is a simple document processor for rendering flat websites.

  USAGE: ark [options] SITEPATH
    where SITEPATH is a path to a valid site directory, or a nonexistant path. If
    the path is nonexistant, a new site will be initialized at the given location.

  Options:
  BANNER



  # TODO: move to interface
  Conf = Trollop.options do
    version Version
    banner Usage
    opt :output,
        "Directory to write output to.",
        :default => nil,
        :type => :string
    opt :verbose,
        "Run verbosely. All messages will be reported."
    opt :quiet,
        "Run silently. Only fatal errors will be reported."
    opt :clean,
        "Remove temporary and cached files after running."
    opt :clobber,
        "Remove previously rendered files, temporary files and cache prior to running."
    opt :validate,
        "Validate rendered HTML with the W3C validator."
    opt :minify,
        "Minify CSS and Javascript files."
  # TODO
  #  opt :plugin, "A comma-seperated list of plugins to load",
  #    :short => :p,
  #    :default => nil
  end

  if Conf[:minify]
    require 'yui/compressor'
  end
  if Conf[:validate]
    require 'w3c_validators'
  end


  # TODO
  #class Plugin
  #end



end # module ARKWEB


AW = ARKWEB

