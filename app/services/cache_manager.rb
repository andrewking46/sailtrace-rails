# class CacheManager
#   CACHE_VERSION = 1

#   def self.fetch(key, expires_in: 1.day, &block)
#     result = Rails.cache.fetch("#{CACHE_VERSION}/#{key}", expires_in:, &block)
#     Rails.logger.info "Cache #{result.nil? ? 'MISS' : 'HIT'} for key: #{key}"
#     result
#   end

#   def self.delete(key)
#     Rails.cache.delete("#{CACHE_VERSION}/#{key}")
#   end

#   def self.clear_all
#     Rails.cache.clear
#   end
# end
