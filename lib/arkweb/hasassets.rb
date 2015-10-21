module ARKWEB

module HasAssets
  attr_reader :assets

  def init_assets(asset_path)
    if self.is_a?(Page)
      if self.composite? || self.index?
        site = self.site
        page = self
      else
        @assets = ClosedStruct.new(
          favicon: false,
          images: ClosedHash.new,
          styles: ClosedHash.new,
          scripts: ClosedHash.new
        )
        return
      end
    elsif self.is_a?(Site)
      site = self
      page = nil
    else
      raise RuntimeError, "Assets can only belong to a Site or Page object"
    end

    images_dir  = asset_path.join('images')
    styles_dir  = asset_path.join('styles')
    scripts_dir = asset_path.join('scripts')

    @assets = ClosedStruct.new do |assets|
      favicon = asset_path.glob(Site::Types.icon).first
      if favicon
        assets.favicon = Favicon.new(site, favicon)
      else
        assets.favicon = false
      end

      assets.images  = ClosedHash.new
      assets.styles  = ClosedHash.new
      assets.scripts = ClosedHash.new

      image_paths  = asset_path.glob(Site::Types.images) + images_dir.glob(Site::Types.images)
      style_paths  = asset_path.glob(Site::Types.style) + styles_dir.glob(Site::Types.style)
      script_paths = asset_path.glob(Site::Types.script) + scripts_dir.glob(Site::Types.script)
     
      image_paths.each do |path|
        img = Image.new(site, path, page)
        assets.images[img.path.basename] = img
      end
      if assets.favicon
        assets.images.delete(assets.favicon.input_path.basename)
      end

      style_paths.each do |path|
        style = Stylesheet.new(site, path, page)
        assets.styles[style.path.basename] = style
      end

      script_paths.each do |path|
        js = Script.new(site, path, page)
        assets.scripts[js.path.basename] = js
      end
    end
  end

  def images
    return @assets.images.values
  end

  def image(name)
    @assets.images.get(name.to_s, iname: 'image', kname: 'name')
  end

  def styles
    return @assets.styles.values
  end

  def style(name)
    @assets.styles.get(name.to_s, iname: 'style', kname: 'name')
  end

  def scripts
    return @assets.scripts.values
  end

  def script(name)
    @assets.scripts.get(name.to_s, iname: 'script', kname: 'name')
  end
end

end # module ARKWEB

