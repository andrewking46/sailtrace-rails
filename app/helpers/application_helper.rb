module ApplicationHelper
  include SailtraceForms::FormHelper
  include MetaTags::BaseHelper
  include MetaTags::SchemaOrgHelper
  include MetaTags::RaceHelper
  include MetaTags::RecordingHelper
  include MetaTags::BoatHelper
  include MetaTags::UserHelper

  def page_title_tag
    tag.title @page_title || "SailTrace"
  end

  def link_back
    link_back_to "javascript:history.back()"
  end

  def link_back_to(destination)
    link_to destination,
            class: "fill flex justify-center align-center fit-content border border-radius-circle padding-block-half padding-inline text-primary text-undecorated shadow" do
      # image_tag("arrow-left.svg", role: "presentation") +
      tag.span(class: "") do
        "&#8592;".html_safe
      end
    end
  end

  def can_administer?
    Current.user&.is_admin?
  end
end
