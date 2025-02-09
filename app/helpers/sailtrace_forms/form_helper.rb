# app/helpers/sailtrace_forms/form_helper.rb
#
# This helper module defines the sailtrace_form_for method which wraps Rails’ form_with,
# automatically setting our custom SailtraceForms::FormBuilder as the builder.
#
# Usage:
#
#   <%= sailtrace_form_for @user do |f| %>
#     <%= f.input :email, as: :email, label: "Email", input_html: { placeholder: "you@example.com" } %>
#     <%= f.input :password, as: :password, label: "Password" %>
#     <%= f.submit "Sign Up", class: "mt-4 w-full ..." %>
#   <% end %>
#
# This helper ensures that every form in the application shares a consistent structure and styling.
module SailtraceForms
  module FormHelper
    # sailtrace_form_for(record, options = {}) { |f| ... }
    #
    # Wraps Rails’ form_with helper so that our custom FormBuilder is automatically used.
    # The helper supports both a symbol (for a scoped form) and an Active Record model.
    def sailtrace_form_for(record, options = {}, &block)
      options[:builder] = SailtraceForms::FormBuilder
      if record.is_a?(Symbol)
        form_with(scope: record, **options, &block)
      else
        form_with(model: record, **options, &block)
      end
    end
  end
end
