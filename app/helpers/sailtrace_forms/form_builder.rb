# app/helpers/sailtrace_forms/form_builder.rb
#
# This custom form builder defines our DSL for building Tailwind–styled form fields.
# It provides a consistent layout with a header (label plus optional right–aligned content),
# an input container (with optional left/right add-ons), and optional description, hint, and error messages.
#
# Key improvements:
# - CSS classes are built from constants and arrays to ease future tweaking.
# - Uses safe_join to build HTML buffers for better readability.
# - Each public method is well–documented so that developers understand what parameters are available.
# - DRY methods for processing collections and rendering field containers.
#
module SailtraceForms
  class FormBuilder < ActionView::Helpers::FormBuilder
    include ActionView::Helpers::TagHelper
    include ActionView::Context

    # ============================================================================
    # CONSTANTS: Default CSS classes for consistency and easier maintenance.
    # ============================================================================

    # Container for the entire input (includes borders, outlines, etc.)
    INPUT_CONTAINER_BASE_CLASSES = [
      "relative",
      "flex",
      "rounded-md",
      "bg-white",
      "dark:bg-white/5",
      "outline-1",
      "-outline-offset-1",
      "outline-gray-950/15",
      "dark:outline-white/20",
      "focus-within:outline-2",
      "focus-within:-outline-offset-2",
      "focus-within:outline-gray-800",
      "dark:focus-within:outline-white",
      "focus:outline-none",
      "before:absolute",
      "before:pointer-events-none",
      "before:inset-px",
      "before:rounded-md",
      "before:shadow-sm",
      "dark:before:hidden"
    ].freeze

    # Default classes for the bare input elements
    DEFAULT_INPUT_CLASSES = [
      "block",
      "min-w-0",
      "grow",
      "py-3",
      "px-4",
      "text-base",
      "text-gray-900",
      "dark:text-white",
      "focus:outline-none"
    ].freeze

    # Additional classes for select fields (which need to remove native appearance)
    SELECT_INPUT_EXTRA_CLASSES = ["appearance-none"].freeze

    # Classes for left/right inline add–ons (icons, prepended text, etc.)
    INLINE_ADDON_CLASSES = "flex-shrink-0 inline-flex items-center text-gray-500 dark:text-white/60 text-base".freeze

    # Classes for field headers (labels)
    HEADER_LABEL_CLASSES = "block text-sm font-medium text-gray-900 dark:text-white".freeze

    # Classes for descriptions, hints, errors, and wrapper container
    DESCRIPTION_CLASSES = "mt-1 text-sm text-gray-500 dark:text-white/60".freeze
    HINT_CLASSES = DESCRIPTION_CLASSES
    ERROR_CLASSES = "mt-2 text-sm text-red-600"
    FIELD_WRAPPER_BASE_CLASSES = "mb-8".freeze

    # ============================================================================
    # PRIVATE HELPER METHODS
    # ============================================================================

    private

    # process_collection(collection, option_text_method=:to_s, option_value_method=:to_s)
    #
    # Normalizes a collection into an array of [label, value, description] tuples.
    # If an item is an array:
    #   - 3 elements: assumed to be [label, value, description]
    #   - 2 elements: returns [label, value, nil]
    # Otherwise, if the item responds to the given text and value methods, those are used.
    # Fallback: converts item to string for both label and value.
    def process_collection(collection, option_text_method = :to_s, option_value_method = :to_s)
      collection.map do |item|
        if item.is_a?(Array)
          case item.size
          when 3 then item
          when 2 then [item[0], item[1], nil]
          else [item.to_s, item.to_s, nil]
          end
        elsif item.respond_to?(option_text_method) && item.respond_to?(option_value_method)
          [item.send(option_text_method), item.send(option_value_method), nil]
        else
          [item.to_s, item.to_s, nil]
        end
      end
    end

    # build_input_container(main_input, left: nil, right: nil, field_type: :text, caret: false, controller: nil)
    #
    # Wraps the core input element together with any inline add–ons (left/right).
    # For select and combobox fields, adds relative positioning so that a caret icon can be absolutely placed.
    #
    # Parameters:
    #   main_input - The core input HTML (as a SafeBuffer).
    #   left       - (Optional) Content to appear to the left of the input.
    #   right      - (Optional) Content to appear to the right of the input.
    #   field_type - The type of field (e.g. :text, :select, :combobox). Determines additional styling.
    #   caret      - Boolean flag to include the caret icon (for select/combobox fields).
    #   controller - (Optional) Stimulus controller name (passed as a data-controller attribute).
    def build_input_container(main_input, left: nil, right: nil, field_type: :text, caret: false, controller: nil)
      # Build the base container classes, adding "relative" for select/combobox fields.
      container_classes = INPUT_CONTAINER_BASE_CLASSES.dup
      container_classes << "relative" if [:select, :combobox].include?(field_type)

      # Build data attributes hash for Stimulus controller if provided.
      data_attrs = {}
      data_attrs[:controller] = controller if controller.present?

      # Build the buffer using safe_join to join the different parts.
      parts = []
      if left.present?
        parts << @template.content_tag(:div, left.to_s, class: "#{INLINE_ADDON_CLASSES} pl-4 -mr-2")
      end
      parts << main_input
      if right.present?
        parts << @template.content_tag(:div, right.to_s, class: "#{INLINE_ADDON_CLASSES} pr-4 -ml-2")
      end
      if caret
        # Render the caret icon. For combobox fields, the button is clickable and triggers the Stimulus action.
        caret_content = if field_type == :combobox
                          @template.button_tag(type: "button",
                                               data: { action: "click->combobox#toggleDropdown" },
                                               class: "#{INLINE_ADDON_CLASSES} absolute right-0 inset-y-0") do
                            caret_icon
                          end
                        else
                          @template.content_tag(:div, caret_icon,
                                                class: "#{INLINE_ADDON_CLASSES} absolute right-0 inset-y-0 pointer-events-none")
                        end
        parts << caret_content
      end

      @template.content_tag(:div, safe_join(parts, "\n"), class: container_classes.join(" "), data: data_attrs)
    end

    # caret_icon
    #
    # Returns the SVG HTML for the caret icon used in select and combobox fields.
    def caret_icon
      @template.content_tag(:span, class: "pointer-events-none relative inset-y-0 right-0 flex items-center px-2") do
        @template.content_tag(:svg, nil,
                              class: "size-5 stroke-gray-500 group-data-disabled:stroke-gray-600 sm:size-4 dark:stroke-gray-400 forced-colors:stroke-[CanvasText]",
                              viewBox: "0 0 16 16",
                              "aria-hidden": "true",
                              fill: "none") do
          safe = ActiveSupport::SafeBuffer.new
          safe << @template.tag.path(
            d: "M5.75 10.75L8 13L10.25 10.75",
            stroke_width: "1.5",
            stroke_linecap: "round",
            stroke_linejoin: "round"
          )
          safe << @template.tag.path(
            d: "M10.25 5.25L8 3L5.75 5.25",
            stroke_width: "1.5",
            stroke_linecap: "round",
            stroke_linejoin: "round"
          )
          safe
        end
      end
    end

    # build_field_container(header_html:, description: nil, input_html:, hint_html: nil, error_html: nil, options: {})
    #
    # Wraps an entire field including the header, description, input container, hint, and error message.
    # This container is what gets rendered into the form.
    #
    # Parameters:
    #   header_html  - The header row HTML (typically the label and any header_right content).
    #   description  - (Optional) A text description below the header.
    #   input_html   - The core input container HTML.
    #   hint_html    - (Optional) A hint message (help text) below the input.
    #   error_html   - (Optional) An error message (if validation fails).
    #   options      - Additional options (supports :wrapper_class for extra container classes).
    def build_field_container(header_html:, description: nil, input_html:, hint_html: nil, error_html: nil, options: {})
      inner_parts = []
      inner_parts << @template.content_tag(:div, header_html, class: "flex items-center justify-between")
      inner_parts << @template.content_tag(:p, description, class: DESCRIPTION_CLASSES) if description.present?
      inner_parts << @template.content_tag(:div, input_html, class: "mt-2")
      inner_parts << @template.content_tag(:p, hint_html, class: HINT_CLASSES) if hint_html.present?
      if error_html.present?
        # The error paragraph is associated with the input via an id for accessibility.
        inner_parts << @template.content_tag(:p, error_html, class: ERROR_CLASSES, id: "#{object_name}_#{@current_method}_error")
      end

      wrapper_classes = [FIELD_WRAPPER_BASE_CLASSES]
      wrapper_classes << options.delete(:wrapper_class) if options[:wrapper_class]
      @template.content_tag(:div, safe_join(inner_parts, "\n"), class: wrapper_classes.join(" "))
    end

    # ============================================================================
    # PUBLIC FIELD METHODS
    # ============================================================================

    public

    # input(method, options = {})
    #
    # Renders a generic input field using our standardized structure.
    #
    # Options include:
    #   :label            - Label text (defaults to humanized method name)
    #   :description      - Field description (placed above the input container)
    #   :hint             - Help text below the input
    #   :prepend          - Text or HTML to prepend to the input
    #   :append           - Text or HTML to append to the input
    #   :leading_icon     - Icon (or other content) to display at the left side
    #   :trailing_icon    - Icon (or other content) to display at the right side
    #   :input_html       - A hash of HTML attributes for the input element
    #   :wrapper_class    - Extra CSS classes for the field wrapper
    #   :as               - Field type (:text, :email, :password, etc.)
    #   :collection       - For select fields: an array of options
    #   :option_text_method - For collection items: method for label (default: :to_s)
    #   :option_value_method - For collection items: method for value (default: :to_s)
    #   :priority_options - For select fields: options to display at the top
    #   :error            - Custom error message (or uses model errors)
    #   :prompt           - Prompt text for select fields
    #   :header_right     - Additional HTML for header’s right–aligned content
    def input(method, options = {})
      @current_method = method

      # Extract options for label, description, hint, and inline add–ons
      label_text    = options.delete(:label)
      description   = options.delete(:description)
      hint_text     = options.delete(:hint)
      prepend       = options.delete(:prepend)
      append        = options.delete(:append)
      leading_icon  = options.delete(:leading_icon)
      trailing_icon = options.delete(:trailing_icon)
      input_html    = options.delete(:input_html) || {}
      wrapper_options = { wrapper_class: options.delete(:wrapper_class) }
      type          = (options.delete(:as) || :text).to_sym
      disabled      = options.delete(:disabled)

      # Get errors from the model if available.
      errors = object.respond_to?(:errors) ? object.errors[method] : []
      error_message = options.delete(:error) || (errors.present? ? errors.join(', ') : nil)

      # Capture the prompt option for select fields.
      prompt_option = options.delete(:prompt)

      # Determine the Rails form helper method to use.
      input_method = case type
                     when :email    then :email_field
                     when :password then :password_field
                     when :textarea then :text_area
                     when :number   then :number_field
                     when :date     then :date_field
                     when :select   then :select
                     when :tel, :telephone then :telephone_field
                     when :url      then :url_field
                     when :file     then :file_field
                     else
                       :text_field
                     end

      # Set a default pattern for telephone inputs if not already provided.
      if [:tel, :telephone].include?(type) && !input_html.key?(:pattern)
        input_html[:pattern] = "[0-9]{10}"
      end

      # Build default CSS classes for the input element.
      input_classes = DEFAULT_INPUT_CLASSES.dup
      input_classes << SELECT_INPUT_EXTRA_CLASSES.first if type == :select
      input_classes << input_html[:class] if input_html[:class].present?
      input_html[:class] = input_classes.join(" ")
      input_html[:disabled] = "disabled" if disabled

      field_input_html =
        if input_method == :select
          # --- SELECT FIELD LOGIC ---
          collection          = options.delete(:collection) || []
          option_text_method  = options.delete(:option_text_method) || :to_s
          option_value_method = options.delete(:option_value_method) || :to_s
          priority            = options.delete(:priority_options)

          # Process collection into [text, value] pairs
          all_options = process_collection(collection, option_text_method, option_value_method)
                          .map { |text, value, _| [text, value] }

          # Determine current (or explicit) selected value
          selected_value =
            if options.key?(:selected)
              options.delete(:selected).to_s.presence
            elsif object.respond_to?(method)
              object.send(method).to_s.presence
            end

          # Pass the prompt through to Rails’ built–in functionality.
          if prompt_option.present?
            options[:prompt] = prompt_option
          elsif selected_value.nil?
            options[:include_blank] = true
          end

          if priority.present?
            priority_options = process_collection(priority, option_text_method, option_value_method)
                                 .map { |text, value, _| [text, value] }
            priority_values = priority_options.map { |_, val| val.to_s }
            main_options = all_options.reject { |_, val| priority_values.include?(val.to_s) }

            options_html = safe_join([
                                       @template.options_for_select(priority_options, selected_value),
                                       (main_options.any? ? @template.content_tag(:option, "---------------", disabled: true) : nil),
                                       (main_options.any? ? @template.options_for_select(main_options, selected_value) : nil)
                                     ].compact, "\n")
            final_options = options_html.html_safe
          else
            final_options = @template.options_for_select(all_options, selected_value)
          end

          field_input_html = @template.select(object_name, method, final_options, options, input_html)
        else
          # --- NON–SELECT FIELD LOGIC ---
          field_input_html = self.send(input_method, method, input_html)
        end

      # Determine inline content (left add–on: prepend or icon; right add–on: append or trailing icon)
      inline_left = prepend || leading_icon
      inline_right = append || trailing_icon

      container_html = build_input_container(field_input_html,
                                             left: inline_left,
                                             right: inline_right,
                                             field_type: type,
                                             caret: [:select, :combobox].include?(type))
      # Build header (label and optional header_right content)
      header = ActiveSupport::SafeBuffer.new
      if label_text != false
        label_text ||= method.to_s.humanize
        header << @template.label(object_name, method, label_text, class: HEADER_LABEL_CLASSES)
      end
      header_right = options.delete(:header_right)
      header << @template.content_tag(:div, header_right, class: "text-sm text-gray-500") if header_right.present?

      # Finally, wrap everything in the field container
      build_field_container(
        header_html: header,
        description: description,
        input_html: container_html,
        hint_html: hint_text,
        error_html: error_message,
        options: wrapper_options
      )
    end

    # check_box_input(method, options = {}, checked_value = "1", unchecked_value = "0")
    #
    # Renders a single checkbox field using a layout similar to a checkbox group option.
    # The manual hidden field is omitted, relying on Rails’ default behavior.
    def check_box_input(method, options = {}, checked_value = "1", unchecked_value = "0")
      @current_method = method
      label_text  = options.delete(:label) { method.to_s.humanize }
      description = options.delete(:description)

      checkbox_id = "#{object_name}_#{method}"
      checkbox = check_box(method, options.merge(id: checkbox_id), checked_value, unchecked_value)

      option_html = @template.content_tag(:div, class: "flex gap-3") do
        input_part = @template.content_tag(:div, checkbox, class: "flex h-6 shrink-0 items-center")
        label_part = @template.content_tag(:div, class: "text-base") do
          lbl = @template.label_tag(checkbox_id, label_text, class: "text-gray-900 dark:text-white")
          lbl += @template.content_tag(:p, description, class: "text-gray-500 dark:text-white/60 text-sm/6") if description.present?
          lbl
        end
        input_part + label_part
      end

      wrapper_classes = [FIELD_WRAPPER_BASE_CLASSES]
      if options[:wrapper_class].present?
        wrapper_classes << options.delete(:wrapper_class)
      end

      @template.content_tag(:div, option_html, class: wrapper_classes.join(" "))
    end

    # radio_group_input(method, collection:, legend: nil, description: nil, selected: nil)
    #
    # Renders a radio button group wrapped in a fieldset. Each option may be a 2– or 3–element array:
    # [label, value, description?]. The selected value is determined either by the passed :selected option or by the model.
    def radio_group_input(method, collection:, legend: nil, description: nil, selected: nil, options: {})
      selected ||= object.respond_to?(method) ? object.send(method).to_s : nil
      processed = process_collection(collection)
      fieldset_parts = []
      fieldset_parts << @template.content_tag(:legend, legend, class: "text-sm font-semibold text-gray-900 dark:text-white") if legend.present?
      fieldset_parts << @template.content_tag(:p, description, class: DESCRIPTION_CLASSES) if description.present?

      radios = processed.map do |option|
        label_text, value, opt_description = option
        radio_id = "#{object_name}_#{method}_#{value}"
        is_checked = (selected.to_s == value.to_s)
        @template.content_tag(:div, class: "flex gap-3 px-4 py-3") do
          input_part = @template.content_tag(:div, class: "flex h-6 shrink-0 items-center") do
            radio_button(method, value, id: radio_id, checked: is_checked)
          end
          label_part = @template.content_tag(:div, class: "text-base") do
            label_tag = @template.label_tag(radio_id, label_text, class: "text-gray-900 dark:text-white")
            desc_part = opt_description.present? ? @template.content_tag(:p, opt_description, class: "text-gray-500 dark:text-white/60 text-sm/6") : ""
            label_tag + desc_part
          end
          input_part + label_part
        end
      end

      fieldset_parts << @template.content_tag(:div, safe_join(radios, "\n"), class: "relative mt-4 rounded-md bg-white dark:bg-white/5 outline-1 -outline-offset-1 outline-gray-950/15 dark:outline-white/20 divide-y divide-gray-950/15 dark:divide-white/20 before:absolute before:pointer-events-none before:inset-px before:rounded-md before:shadow-sm dark:before:hidden")

      wrapper_classes = [FIELD_WRAPPER_BASE_CLASSES]
      if options[:wrapper_class].present?
        wrapper_classes << options.delete(:wrapper_class)
      end

      @template.content_tag(:fieldset, safe_join(fieldset_parts, "\n"), class: wrapper_classes.join(" "))
    end

    # checkbox_group_input(method, collection:, legend: nil, description: nil, selected: [])
    #
    # Renders a group of checkboxes wrapped in a fieldset. Each option is a 2– or 3–element array.
    # The :selected option should be an array (even if it contains a single value).
    def checkbox_group_input(method, collection:, legend: nil, description: nil, selected: [], options: {})
      selected = Array(selected).map(&:to_s)
      if selected.empty? && object.respond_to?(method)
        selected = Array(object.send(method)).map(&:to_s)
      end
      processed = process_collection(collection)
      fieldset_parts = []
      fieldset_parts << @template.content_tag(:legend, legend, class: "text-sm font-semibold text-gray-900 dark:text-white") if legend.present?
      fieldset_parts << @template.content_tag(:p, description, class: DESCRIPTION_CLASSES) if description.present?

      checkboxes = processed.map do |option|
        label_text, value, opt_description = option
        checkbox_id = "#{object_name}_#{method}_#{value}"
        is_checked = selected.include?(value.to_s)
        @template.content_tag(:div, class: "flex gap-3 px-4 py-3") do
          input_part = @template.content_tag(:div, class: "flex h-6 shrink-0 items-center") do
            check_box(method, { id: checkbox_id, checked: is_checked }, value, nil)
          end
          label_part = @template.content_tag(:div, class: "text-base") do
            label_tag = @template.label_tag(checkbox_id, label_text, class: "text-gray-900 dark:text-white")
            desc_part = opt_description.present? ? @template.content_tag(:p, opt_description, class: "text-gray-500 dark:text-white/60 text-sm/6") : ""
            label_tag + desc_part
          end
          input_part + label_part
        end
      end

      fieldset_parts << @template.content_tag(:div, safe_join(checkboxes, "\n"), class: "relative mt-4 rounded-md bg-white dark:bg-white/5 outline-1 -outline-offset-1 outline-gray-950/15 dark:outline-white/20 divide-y divide-gray-950/15 dark:divide-white/20 before:absolute before:pointer-events-none before:inset-px before:rounded-md before:shadow-sm dark:before:hidden")

      wrapper_classes = [FIELD_WRAPPER_BASE_CLASSES]
      if options[:wrapper_class].present?
        wrapper_classes << options.delete(:wrapper_class)
      end

      @template.content_tag(:fieldset, safe_join(fieldset_parts, "\n"), class: wrapper_classes.join(" "))
    end

    # textarea_input(method, options = {})
    #
    # Renders a textarea by simply aliasing the input method with :textarea type.
    def textarea_input(method, options = {})
      options[:as] ||= :textarea
      input(method, options)
    end

    # combobox_input(method, options = {})
    #
    # Renders a combobox (a text input with a filterable dropdown) using our standardized layout.
    # The combobox consists of a text input, a toggleable dropdown list, and a caret icon.
    # The dropdown list is built from the provided collection.
    def combobox_input(method, options = {})
      @current_method = method
      label_text          = options.delete(:label)
      description         = options.delete(:description)
      hint_text           = options.delete(:hint)
      input_html          = options.delete(:input_html) || {}
      wrapper_options     = { wrapper_class: options.delete(:wrapper_class) }
      collection          = options.delete(:collection) || []
      option_text_method  = options.delete(:option_text_method) || :to_s
      option_value_method = options.delete(:option_value_method) || :to_s
      disabled            = options.delete(:disabled)

      errors = object.respond_to?(:errors) ? object.errors[method] : []
      error_message = options.delete(:error) || (errors.present? ? errors.join(', ') : nil)

      # Process the collection into [display, value, description] tuples.
      opts = process_collection(collection, option_text_method, option_value_method)

      # Determine the underlying selected value from the model.
      selected_value = object.respond_to?(method) ? object.send(method).to_s : ""
      # Look up the display text matching the underlying value.
      display_value = ""
      opts.each do |text, value, _|
        if value.to_s == selected_value.to_s
          display_value = text
          break
        end
      end
      # Allow an override if input_html contains a preset display value.
      display_value = input_html.delete(:value) if input_html[:value].present?

      # Ensure the visible text field has the proper Stimulus target.
      input_html[:data] ||= {}
      input_html[:data].merge!({ combobox_target: "input" })

      # Build default CSS classes for the visible text field.
      input_classes = DEFAULT_INPUT_CLASSES.dup
      input_classes << "appearance-none"
      if disabled
        input_classes << "disabled:cursor-not-allowed"
        input_classes << "disabled:bg-gray-50 dark:disabled:bg-gray-700"
        input_classes << "disabled:text-gray-500 disabled:border-gray-200 dark:disabled:border-gray-500"
      end
      input_classes << input_html[:class] if input_html[:class].present?
      input_html[:class] = input_classes.join(" ")
      input_html[:disabled] = "disabled" if disabled

      # Build the hidden field for storing the underlying value.
      hidden_field_html = self.hidden_field(method, value: selected_value, data: { combobox_target: "hidden" }, id: "#{object_name}_#{method}_hidden", class: "hidden")

      # Build the visible text field for display and filtering.
      # Remove the "name" attribute so it is not submitted.
      visible_input_html = input_html.dup
      visible_input_html[:id] = "#{object_name}_#{method}"
      visible_input_html.delete(:name)
      visible_input_html[:value] = display_value
      # Use text_field_tag (which lets us omit the name) so the form submission relies on the hidden field.
      visible_field = @template.text_field_tag(nil, display_value, visible_input_html)

      # Build the dropdown list; each option carries its underlying value.
      dropdown = @template.content_tag(:ul,
                                       safe_join(
                                         opts.map do |display, value, _desc|
                                           @template.content_tag(:li, display,
                                                                 class: "cursor-pointer select-none py-3 px-3 rounded-sm hover:bg-gray-100 dark:hover:bg-white/10",
                                                                 data: { action: "click->combobox#selectOption", value: value })
                                         end, "\n"
                                       ),
                                       class: "absolute z-10 top-full w-full mt-1 max-h-60 overflow-auto rounded-md bg-white dark:bg-zinc-800 p-1 text-base text-gray-900 dark:text-white shadow-lg ring-1 ring-black/5 dark:ring-white/10 hidden",
                                       data: { combobox_target: "dropdown" }
      )

      # Compose the overall combobox field with the hidden field, visible field, and dropdown.
      combobox_field = @template.content_tag(:div, class: "relative flex w-full") do
        safe_join([
                    hidden_field_html,
                    visible_field,
                    dropdown
                  ], "\n")
      end

      # Render the combobox container with a caret (and attach the Stimulus controller).
      container_html = build_input_container(combobox_field,
                                             field_type: :combobox,
                                             caret: true,
                                             controller: "combobox")
      header = ActiveSupport::SafeBuffer.new
      if label_text != false
        label_text ||= method.to_s.humanize
        header << @template.label(object_name, method, label_text, class: HEADER_LABEL_CLASSES)
      end

      build_field_container(
        header_html: header,
        description: description,
        input_html: container_html,
        hint_html: hint_text,
        error_html: error_message,
        options: wrapper_options
      )
    end

    # file_upload_input(method, options = {})
    #
    # Renders a file upload field that hides the native file input (using "sr-only")
    # and instead shows a custom “Change” button with an icon.
    def file_upload_input(method, options = {})
      @current_method = method
      label_text   = options.delete(:label)
      description  = options.delete(:description)
      hint_text    = options.delete(:hint)
      input_html   = options.delete(:input_html) || {}
      wrapper_options = { wrapper_class: options.delete(:wrapper_class) }
      disabled     = options.delete(:disabled)

      input_html[:class] = "sr-only"
      input_html[:disabled] = "disabled" if disabled

      header = ActiveSupport::SafeBuffer.new
      if label_text != false
        label_text ||= method.to_s.humanize
        header << @template.label(object_name, method, label_text, class: HEADER_LABEL_CLASSES)
      end

      file_upload_field = @template.content_tag(:div, class: "mt-2 flex items-center gap-x-3") do
        safe_join([
                    @template.content_tag(:svg, nil,
                                          class: "w-12 h-12 text-gray-400 dark:text-gray-300",
                                          viewBox: "0 0 24 24",
                                          fill: "currentColor",
                                          "aria-hidden": "true") do
                      @template.concat @template.tag.path(d: "M16.5 2.75H7.5a2.75 2.75 0 00-2.75 2.75v13a2.75 2.75 0 002.75 2.75h9a2.75 2.75 0 002.75-2.75v-13a2.75 2.75 0 00-2.75-2.75zM10 17l-3-3 1.06-1.06L10 14.88l5.94-5.94L17 10l-7 7z")
                    end,
                    @template.label(object_name, method,
                                    class: "rounded-md bg-gray-200 dark:bg-gray-700 px-4 py-3 text-sm font-semibold text-gray-900 dark:text-white cursor-pointer hover:bg-gray-300 dark:hover:bg-gray-600") do
                      safe_join([
                                  "Change",
                                  self.file_field(method, input_html)
                                ], "")
                    end
                  ], "\n")
      end

      build_field_container(
        header_html: header,
        description: description,
        input_html: file_upload_field,
        hint_html: hint_text,
        options: wrapper_options
      )
    end
  end
end
