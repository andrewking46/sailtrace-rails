module Cacheable
  extend ActiveSupport::Concern

  class_methods do
    def cache_key(id)
      "#{name.underscore}/#{id}"
    end
  end

  def cache_key
    self.class.cache_key(id)
  end
end
