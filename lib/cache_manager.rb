# frozen_string_literal: true

class CacheManager
  CACHE_VERSION = 1

  # We log hits/misses to help track usage.
  def self.fetch(key, expires_in: 1.day, &block)
    namespaced_key = "#{CACHE_VERSION}/#{key}"
    Rails.cache.fetch(namespaced_key, expires_in:, &block).tap do |value|
      Rails.logger.info "Cache fetch for #{namespaced_key} => #{value.nil? ? 'MISS' : 'HIT'}"
    end
  end

  def self.read(key)
    namespaced_key = "#{CACHE_VERSION}/#{key}"
    Rails.cache.read(namespaced_key).tap do |value|
      Rails.logger.info "Cache read for #{namespaced_key} => #{value.nil? ? 'MISS' : 'HIT'}"
    end
  end

  def self.write(key, data, expires_in: 1.day)
    namespaced_key = "#{CACHE_VERSION}/#{key}"
    Rails.cache.write(namespaced_key, data, expires_in:)
  end

  def self.delete(key)
    namespaced_key = "#{CACHE_VERSION}/#{key}"
    Rails.cache.delete(namespaced_key)
  end

  def self.clear_all
    Rails.cache.clear
  end
end
