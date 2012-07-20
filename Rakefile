require 'rake'
require 'rdoc/task'
require 'rubygems/package_task'
require 'rspec/core/rake_task'
require 'fileutils'
require 'erb'

load 'lib/arkweb-3.rb'



RSpec::Core::RakeTask.new 'spec' do |t|
  t.pattern = './spec/*.rb'
end

spec = Gem::Specification.new do |s|
  s.name = AW::Project['name'].downcase
  s.version = "#{AW::Project['version']}.0"
  s.author      = 'Nathan Gifford'
  s.email       = 'nn@studio25.org'
  s.description = 'ARKWEB the _inscrutable_ web publisher
                   publishes your webs
                   and smashes thru doors
                   but o! what a pitiful metaphor'
  s.summary     = 'ARKWEB the _inscrutable_ web publisher'
  s.homepage    = 'http://studio25.org/projects/arkweb'
  s.bindir      = 'bin'
  s.files        = Dir.glob("{bin,lib,templates}/**/*") + %w(LICENSE README project.yaml)
  s.executables  = ['ark']
  s.require_path = 'lib'
end

Gem::PackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end

Rake::RDocTask.new do |rd|
  rd.main       = 'README'
  rd.rdoc_dir   = 'doc'
  rd.title      = "ARKWEB #{AW::Project['version']} '#{AW::Project['codename']}'"
  rd.rdoc_files = Dir['bin/*'] + Dir['lib/*']
end


task :run do
  site = ARKWEB::Site.new('test/site')
  site.compile()
  site.deploy()
end

task :build => :gem do
  FileUtils.mv("pkg/#{AW::Project['name'].downcase}-#{AW::Project['version']}.0.gem", '.')
end

task :pack => :build do
  @version = "#{AW::Pr['version']}.0"
  @md5 = `makepkg -g 2> /dev/null`
  File.open('PKGBUILD.erb', 'r') do |f|
    erb = ERB.new(f.read)
    pb = erb.result(binding)
    File.open('PKGBUILD', 'w') {|o| o.write(pb) }
  end
  system('makepkg -fc')
  system('makepkg -f --source')
end

