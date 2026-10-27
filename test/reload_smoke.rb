# Run from the Redmine root with:
# RAILS_ENV=development bundle exec rails runner plugins/redmine_serial_number_field/test/reload_smoke.rb
3.times do |cycle|
  Rails.application.eager_load!
  raise 'format registration lost' unless Redmine::FieldFormat.find('serial_number').class == SerialNumberField::Format
  raise 'issue patch registration' unless Issue.ancestors.count { |klass| klass.name == 'SerialNumberField::IssuePatch' } == 1
  raise 'custom field patch registration' unless IssueCustomField.ancestors.count { |klass| klass.name == 'SerialNumberField::IssueCustomFieldPatch' } == 1
  hooks = Redmine::Hook.listeners.select { |hook| hook.class.name == 'SerialNumberField::IssueViewHooks' }
  raise 'hook registration' unless hooks.size == 1 && hooks.first.class == SerialNumberField::IssueViewHooks
  puts "cycle #{cycle}: eager loading and registrations OK"
  Rails.application.reloader.reload!
end
