class CacheManager
  CACHE_VERSION = 1

  class << self
    def fetch(key, expires_in: 1.week, &block)
      SolidCache.fetch("#{CACHE_VERSION}/#{key}", expires_in: expires_in, &block)
    end

    def delete(key)
      SolidCache.delete("#{CACHE_VERSION}/#{key}")
    end

    def clear_all
      SolidCache.clear
    end
  end
end
