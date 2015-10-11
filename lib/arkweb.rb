### ARKWEB

require 'fileutils'
require 'yaml'
require 'erb'
require 'pathname'
require 'open-uri'
require 'ostruct'

require 'ark/util'
require 'ark/cli'

require_relative 'arkweb/patches'
require_relative 'arkweb/closedstruct'
require_relative 'arkweb/error'
require_relative 'arkweb/application'
require_relative 'arkweb/site'
require_relative 'arkweb/path'
require_relative 'arkweb/favicon'
require_relative 'arkweb/page'
require_relative 'arkweb/image'
require_relative 'arkweb/script'
require_relative 'arkweb/stylesheet'
require_relative 'arkweb/section'
require_relative 'arkweb/helper'
require_relative 'arkweb/engine'
require_relative 'arkweb/interface'

include ARK::Log


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

end # module ARKWEB

AW = ARKWEB

