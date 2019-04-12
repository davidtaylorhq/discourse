module SiteIconManager
  %i{
    manifest_icon
    favicon
  }.each do |name|
    define_singleton_method("#{name}_url") do
      icon = self.public_send(name)
      icon&.url
    end

    define_singleton_method("absolute_#{name}_url") do
      url = self.public_send("#{name}_url")
      full_cdn_url(url)
    end
  end

  def self.fallback_icon
    SiteSetting.large_icon || SiteSetting.logo_small
  end

  def self.manifest_icon
    OptimizedImage.create_for(fallback_icon, 512, 512)
  end

  def self.favicon
    SiteSetting.favicon || OptimizedImage.create_for(fallback_icon, 512, 512)
  end
end
