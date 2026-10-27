Redmine::Plugin.register :redmine_serial_number_field do
  name 'Redmine Serial Number Field'
  author 'Matsukei Co.,Ltd'
  description 'Add a format to be serial number in the specified format as a issue custom field.'
  version '4.0.0'
  requires_redmine version_or_higher: '7.0.0'
  url 'https://github.com/nepnyan3/redmine_serial_number_field'
  author_url 'http://www.matsukei.co.jp/'
end

# Redmine runs plugin initializers on each Rails prepare/reload cycle.
SerialNumberField::Format
Issue.include SerialNumberField::IssuePatch unless Issue < SerialNumberField::IssuePatch
IssueCustomField.prepend SerialNumberField::IssueCustomFieldPatch unless IssueCustomField < SerialNumberField::IssueCustomFieldPatch
SerialNumberField::IssueViewHooks
