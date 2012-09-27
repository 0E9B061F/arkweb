#!/usr/bin/env ruby

require 'test/unit'
load 'lib/arkweb-3.rb'

class TestCaseSite < Test::Unit::TestCase

  Header = YAML.load_file('test/site/header.yaml')


  ### ### Helpers

  def assert_head(site, *params)
    params.each do |p|
      value = site.send(p)
      assert value,
      "Site.#{p}: parameter is nil or false."
      assert value == Header[p.to_s],
      "Site.#{p}: expected `#{Header[p.to_s]}', got `#{value}'"
    end
  end


  ### ### Tests

  def test_initialize
    assert_raise AW::BrokenSiteError do
      AW::Site.new('test/site-malformed-header')
    end
    assert_raise AW::BrokenSiteError do
      AW::Site.new('test/site-missing-header')
    end

    site = AW::Site.new('test/site')
    assert_head(site, :title, :desc, :author, :tags)
    assert site.keywords == site.tags.join(', ')

  end

end



class TestCaseInterface < Test::Unit::TestCase

  def test_site_init
    FileUtils.rm_r('test/site-init') if File.directory?('test/site-init') # XXX move to teardown or setup
    AW::Interface.run('test/site-init')
    skel = Dir['test/site-init/*'].map {|p| File.basename(p) }
    init = Dir['skel/*'].map {|p| File.basename(p) }
    assert skel == init,
    "Initialized site contents do not match skeletal site contents."

    Dir['site/skel/*'].each do |path|
      if File.file?(path)
        File.open(path, 'r') do |ref|
          out = File.join('test/site-init', File.basename(path))
          File.open(out, 'r') {|test| assert ref.read == test.read }
        end
      end
    end

  end

end



class TestCaseEngine < Test::Unit::TestCase

  # Test page rendering with each format
  def test_render_page
    site = AW::Site.new('test/site')

    formats = %w[ erb md wiki ]
    formats.each do |format|
      page = "test/site/test-#{format}.#{format}.page"
      html = File.open("test/html/test-#{format}.html", 'r') {|f| f.read }
      site.engine.render_page(page)
      assert site.engine.pages[page] == html
    end
  end

end

class TestCaseBin < Test::Unit::TestCase
  def assert_argv(argv, mode=true)
    assert system("bin/ark #{argv} &> /dev/null") == mode
  end

  def test_bin
    assert_argv('-h')
    assert_argv('--version')
    assert_argv('test/site-init')
    assert_argv('test/site')
    assert_argv('-v test/site')
    assert_argv('-q test/site')
    assert_argv('-o /tmp/test-html test/site')
    assert_argv('-vq -o /tmp/test-html test/site')
    assert_argv('-x', false)
  end
end

