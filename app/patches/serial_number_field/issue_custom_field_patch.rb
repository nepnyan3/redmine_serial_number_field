module SerialNumberField
  module IssueCustomFieldPatch
    extend ActiveSupport::Concern

    def validate_custom_field
      super

      # The field contains a serial template, not a Ruby regular expression.
      # Remove only Redmine's generic regexp error; keep template errors.
      errors.delete(:regexp, :invalid) if field_format == SerialNumberField::Format::NAME
    end
  end
end
