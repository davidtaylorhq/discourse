module SiteIconManager

  @cache = DistributedCache.new('icon_manager')

  ICONS = {
    manifest_icon: { width: 512, height: 512, original: -> { nil }, fallback_to_original: true },
    favicon: { width: 32, height: 32, original: -> { SiteSetting.favicon }, fallback_to_original: false },
    apple_touch_icon: { width: 180, height: 180, original: -> { SiteSetting.apple_touch_icon }, fallback_to_original: false },
    opengraph_image: { width: nil, height: nil, original: -> { SiteSetting.opengraph_image }, fallback_to_original: true }
  }

  def self.fallback_icon
    SiteSetting.large_icon || SiteSetting.logo_small
  end

  def self.ensure_optimized!
    ICONS.each do |name, info|
      icon = info[:original].call || fallback_icon
      if info[:height] && info[:width]
        OptimizedImage.create_for(icon, info[:width], info[:height])
      end
    end
    @cache.clear
  end

  ICONS.each do |name, info|
    define_singleton_method(name) do
      icon = info[:original].call || fallback_icon
      if info[:height] && info[:width]
        result = OptimizedImage.find_by(upload: icon, height: info[:height], width: info[:width])
      end
      result = icon if !result && info[:fallback_to_original]
      result
    end

    define_singleton_method("#{name}_url") do
      get_set_cache("#{name}_url") do
        icon = self.public_send(name)
        icon&.url
      end
    end

    define_singleton_method("absolute_#{name}_url") do
      url = self.public_send("#{name}_url")
      UrlHelper.absolute(url)
    end
  end

  def self.get_set_cache(key, &blk)
    if val = @cache[key]
      return val
    end
    @cache[key] = blk.call
  end

end
