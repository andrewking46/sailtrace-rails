class CacheManager
  CACHE_VERSION = 1

  class << self
    def self.fetch(key, expires_in: 1.week, &block)
      result = SolidCache.fetch("#{CACHE_VERSION}/#{key}", expires_in: expires_in, &block)
      Rails.logger.info "Cache #{result.nil? ? 'MISS' : 'HIT'} for key: #{key}"
      result
    end

    def delete(key)
      SolidCache.delete("#{CACHE_VERSION}/#{key}")
    end

    def clear_all
      SolidCache.clear
    end
  end
end
