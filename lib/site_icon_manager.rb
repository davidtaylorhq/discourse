module SiteIconManager
  %i{
    manifest_icon
    favicon
    apple_touch_icon
    opengraph_image
  }.each do |name|
    define_singleton_method("#{name}_url") do
      icon = self.public_send(name)
      icon&.url
    end

    define_singleton_method("absolute_#{name}_url") do
      url = self.public_send("#{name}_url")
      UrlHelper.absolute(url)
    end
  end

  def self.fallback_icon
    SiteSetting.large_icon || SiteSetting.logo_small
  end

  def self.manifest_icon
    # Always resize, must be exactly 512x512
    OptimizedImage.create_for(fallback_icon, 512, 512)
  end

  def self.favicon
    # Use supplied version if present, otherwise generate one
    SiteSetting.favicon || OptimizedImage.create_for(fallback_icon, 512, 512)
  end

  def self.apple_touch_icon
    # Always resize, must be exactly 180x180
    icon = SiteSetting.apple_touch_icon || fallback_icon
    OptimizedImage.create_for(icon, 180, 180)
  end

  def self.opengraph_image
    # No specific size requirement, supply the originals
    SiteSetting.opengraph_image || fallback_icon
  end
end
