module MetaTags
  module BaseHelper
    # Generate all meta tags including OpenGraph, Twitter Card, and Schema.org
    # @param options [Hash] Options for generating meta tags
    # @option options [String] :title The title of the page
    # @option options [String] :description A brief description of the page content
    # @option options [String, Hash] :image The image to use (URL, path, or ActiveStorage attachment)
    # @option options [String] :url The canonical URL of the page
    # @option options [String] :type ('website') The type of content
    # @option options [String] :schema_type ('WebPage') The Schema.org type
    # @return [ActiveSupport::SafeBuffer] HTML meta tags
    def meta_tags(options = {})
      tags = []
      tags << open_graph_tags(options)
      tags << twitter_card_tags(options)
      tags << schema_org_tags(options)
      safe_join(tags, "\n")
    end

    private

    def open_graph_tags(options)
      [
        tag.meta(property: "og:title", content: options[:title] || default_title),
        tag.meta(property: "og:description", content: options[:description] || default_description),
        tag.meta(property: "og:image", content: resolve_image_url(options[:image])),
        tag.meta(property: "og:url", content: options[:url] || request.original_url),
        tag.meta(property: "og:type", content: options[:type] || "website"),
        tag.meta(property: "og:site_name", content: "SailTrace")
      ]
    end

    def twitter_card_tags(options)
      [
        tag.meta(name: "twitter:card", content: "summary_large_image"),
        tag.meta(name: "twitter:site", content: "SailTrace"),
        tag.meta(name: "twitter:title", content: options[:title] || default_title),
        tag.meta(name: "twitter:description", content: options[:description] || default_description),
        tag.meta(name: "twitter:image", content: resolve_image_url(options[:image]))
      ]
    end

    def schema_org_tags(options)
      content = generate_schema_org(options[:entity], options[:schema_type])
      tag.script(content.to_json.html_safe, type: "application/ld+json")
    end

    def resolve_image_url(image)
      case image
      when String
        image.start_with?("http") ? image : asset_url(image)
      when Hash
        rails_representation_url(image)
      when ActiveStorage::Attached::One
        rails_blob_url(image)
      else
        asset_url("logos/logo-orange-background.png")
      end
    end

    def default_title
      I18n.t("meta_tags.default_title", default: "SailTrace")
    end

    def default_description
      I18n.t("meta_tags.default_description",
             default: "SailTrace helps sailors record, replay, and analyze their races.")
    end
  end
end
