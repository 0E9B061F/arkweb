require 'test/unit'
load 'lib/arkweb-3.rb'

class TestCaseARKWEB < Test::Unit::TestCase

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
    assert site.description == site.desc
    assert site.keywords == site.tags.join(', ')
  end

  # Test page rendering with each format
  def test_render_page
    # test ERB
    site = AW::Site.new('test/site')
    eng  = AW::Engine.new(site)
    eng.render_page('test/site/test.erb.page')
    assert eng.pages['test/site/test.erb.page']

    # test md
    # test wiki
  end

end

