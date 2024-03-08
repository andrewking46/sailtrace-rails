module ApplicationHelper
  def page_title_tag
    tag.title @page_title || "SailTrace"
  end

  def link_back
    link_back_to "javascript:history.back()"
  end

  def link_back_to(destination)
    link_to destination, class: "fill border border-radius padding-block-half padding-inline text-primary text-undecorated" do
      # image_tag("arrow-left.svg", role: "presentation") +
      tag.span(class: "") do
        "&#8592;".html_safe + " Back"
      end
    end
  end
end
