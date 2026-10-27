module SerialNumberField
  class Format < Redmine::FieldFormat::Base
    NAME = 'serial_number'
    add NAME
    self.searchable_supported = true
    self.customized_class_names = %w(Issue)
    self.form_partial = 'custom_fields/formats/serial_number'

    FORMAT_WRAPPER = /\{([^{}]+)\}/
    DATE_FORMATS = {
      'yyyy' => '%Y', 'yy' => '%y', 'YYYY' => '%Y', 'YY' => '%y', 'ISO' => '%Y%m%d'
    }.freeze

    def validate_custom_field(custom_field)
      template = custom_field.regexp.to_s
      errors = []
      unless template.match?(/\{0+\}\z/)
        errors << [:regexp, :end_must_numeric_format_in_serial_number]
      end
      remainder = template.gsub(FORMAT_WRAPPER) do
        token = Regexp.last_match(1)
        unless token.match?(/\A0+\z/) || DATE_FORMATS.key?(token)
          errors << [:regexp, :invalid_format_in_serial_number]
        end
        ''
      end
      if remainder.match?(/[{}]/)
        errors << [:regexp, :invalid_format_in_serial_number]
      end
      errors.uniq
    end

    # Called while holding the custom field's row lock in the issue transaction.
    # The final numeric token is a minimum width, never a carry into the prefix.
    def generate_value(custom_field, issue)
      template = custom_field.regexp
      width = template.match(/\{(0+)\}\z/)[1].length
      datetime = (issue.created_on || Time.current).to_datetime
      prefix = expand(template.sub(/\{0+\}\z/, ''), datetime)
      matcher = /\A#{Regexp.escape(prefix)}(\d{#{width},})\z/
      values = CustomValue.uncached do
        CustomValue.where(custom_field_id: custom_field.id, customized_type: 'Issue').pluck(:value)
      end
      maximum = values.filter_map do |value|
        match = matcher.match(value.to_s)
        match[1].to_i if match
      end.max || 0
      prefix + (maximum + 1).to_s.rjust(width, '0')
    end

    private

    def expand(template, datetime)
      template.gsub(FORMAT_WRAPPER) do
        token = Regexp.last_match(1)
        if DATE_FORMATS.key?(token)
          date = datetime
          if %w(YYYY YY).include?(token)
            date = Date.new(datetime.year - (datetime.month < 4 ? 1 : 0), 4, 1)
          end
          date.strftime(DATE_FORMATS.fetch(token))
        else
          '1'.rjust(token.length, '0')
        end
      end
    end
  end
end
