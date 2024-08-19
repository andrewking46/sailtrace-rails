module JsonCacheable
  extend ActiveSupport::Concern

  def render_cached_json(record)
    json_data = CacheManager.fetch("#{record.cache_key}/json") do
      render_to_string(formats: :json, locals: { record.class.name.underscore.to_sym => record })
    end
    render json: json_data
  end
end
