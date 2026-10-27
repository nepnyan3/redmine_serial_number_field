require File.expand_path('../../test_helper', __FILE__)

class SerialNumberField::IssueTest < ActiveSupport::TestCase
  fixtures :projects,
           :users, :email_addresses, :user_preferences,
           :roles, :members, :member_roles,
           :issues, :issue_statuses, :issue_relations,
           :versions, :trackers, :projects_trackers,
           :issue_categories, :enabled_modules,
           :enumerations, :attachments, :workflows,
           :custom_fields, :custom_values,
           :custom_fields_projects, :custom_fields_trackers,
           :time_entries, :journals, :journal_details,
           :queries, :repositories, :changesets

  include Redmine::I18n

  def setup
    set_language_if_valid 'en'
    @default_custom_field = create_default_serial_number_field
  end

  def teardown
    User.current = nil
  end

  def test_create_with_changed_serial_number_halfway
    issue = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => 3, :subject => 'test_create_1')
    assert issue.save
    assert_added_serial_number(issue.id, 'MCC-0001', @default_custom_field)

    # changed regexp(forced)
    @default_custom_field.update(regexp: 'ABC-{0001}')

    issue = Issue.new(:project_id => 1, :tracker_id => 3, :author_id => 3, :subject => 'test_create_2')
    assert issue.save
    assert_added_serial_number(issue.id, 'MCC-0002', @default_custom_field)
  end

  def test_serial_values_are_server_generated_and_stable_on_repeated_save
    issue = Issue.new(project_id: 1, tracker_id: 1, author_id: 3, subject: 'Server generated')
    issue.custom_field_values = {@default_custom_field.id.to_s => 'MCC-9999'}
    issue.save!
    assert_equal 'MCC-0001', issue.custom_field_value(@default_custom_field)
    issue.reload # Redmine's nested-set insertion updates the stored lock version.
    issue.custom_field_values = {@default_custom_field.id.to_s => 'FORGED'}
    issue.subject = 'Updated'
    issue.save!
    assert_added_serial_number(issue.id, 'MCC-0001', @default_custom_field)
    assert_equal 'MCC-0001', issue.custom_field_value(@default_custom_field)
  end

  def test_copy_gets_a_new_number_only_once
    User.current = User.find(2)
    original = Issue.create!(project_id: 1, tracker_id: 1, author_id: 2, subject: 'Original')
    copy = Issue.new.copy_from(original)
    copy.save!
    assert_added_serial_number(copy.id, 'MCC-0002', @default_custom_field)
    copy.reload
    copy.subject = 'Copy updated'
    copy.save!
    assert_added_serial_number(copy.id, 'MCC-0002', @default_custom_field)
  end

  def test_calendar_and_japanese_fiscal_year_formats
    {
      '{yyyy}-{0000}' => ['2025-0001', '2025-0001'],
      '{yy}-{0000}' => ['25-0001', '25-0001'],
      '{YYYY}-{0000}' => ['2024-0001', '2025-0001'],
      '{YY}-{0000}' => ['24-0001', '25-0001'],
      '{ISO}-{0000}' => ['20250331-0001', '20250401-0001']
    }.each do |template, expected|
      @default_custom_field.regexp = template
      ['2025-03-31', '2025-04-01'].each_with_index do |date, i|
        issue = Issue.new(created_on: Time.parse("#{date} 12:00:00 UTC"))
        assert_equal expected[i], @default_custom_field.format.generate_value(@default_custom_field, issue)
      end
    end
  end

  def test_year_change_resets_numbering_using_issue_creation_date
    @default_custom_field.update!(regexp: '{yyyy}-{0000}')
    @default_custom_field.custom_values.create!(customized: Issue.find(1), value: '2024-0099')
    issue = Issue.new(created_on: Time.utc(2025, 1, 1))
    assert_equal '2025-0001', @default_custom_field.format.generate_value(@default_custom_field, issue)
    issue.created_on = Time.utc(2024, 12, 31)
    assert_equal '2024-0100', @default_custom_field.format.generate_value(@default_custom_field, issue)
  end

  def test_counter_continues_after_exceeding_minimum_width
    @default_custom_field.update!(regexp: 'ABC-{00}')
    ['ABC-98', 'ABC-99', 'ABC-100'].each do |value|
      @default_custom_field.custom_values.create!(customized: Issue.find(1), value: value)
    end
    assert_equal 'ABC-101', @default_custom_field.format.generate_value(@default_custom_field, Issue.find(1))
  end

  def test_prefix_is_literal_and_match_is_anchored
    @default_custom_field.update!(regexp: '[日本語]+.{00}')
    ['[日本語]+.01', 'unrelated[日本語]+.98', '[日本語]+.99suffix'].each do |value|
      @default_custom_field.custom_values.create!(customized: Issue.find(1), value: value)
    end
    assert_equal '[日本語]+.02', @default_custom_field.format.generate_value(@default_custom_field, Issue.find(1))
  end

  def test_literal_digits_before_counter_and_multiple_numeric_groups
    @default_custom_field.update!(regexp: '{00}-0{00}')
    @default_custom_field.custom_values.create!(customized: Issue.find(1), value: '01-099')
    assert_equal '01-0100', @default_custom_field.format.generate_value(@default_custom_field, Issue.find(1))
  end

  def test_malformed_templates_keep_specific_validation_errors
    [nil, '', '{unknown}-{00}', '{yyyy-{00}', '{00}suffix', "{00}\n"].each do |template|
      field = IssueCustomField.new(name: 'invalid', field_format: 'serial_number', regexp: template)
      assert_not field.valid?, template.inspect
      assert field.errors[:regexp].present?, template.inspect
    end
  end

  def test_number_allocation_rolls_back_with_the_issue_transaction
    Issue.transaction(requires_new: true) do
      Issue.create!(project_id: 1, tracker_id: 1, author_id: 2, subject: 'Rolled back')
      raise ActiveRecord::Rollback
    end
    issue = Issue.create!(project_id: 1, tracker_id: 1, author_id: 2, subject: 'After rollback')
    assert_added_serial_number(issue.id, 'MCC-0001', @default_custom_field)
  end

  def test_fiscal_year_sequence_resets_on_april_first
    @default_custom_field.update!(regexp: '{YYYY}-{00}')
    @default_custom_field.custom_values.create!(customized: Issue.find(1), value: '2024-09')
    march = Issue.new(created_on: Time.utc(2025, 3, 31, 23, 59, 59))
    april = Issue.new(created_on: Time.utc(2025, 4, 1))
    assert_equal '2024-10', @default_custom_field.format.generate_value(@default_custom_field, march)
    assert_equal '2025-01', @default_custom_field.format.generate_value(@default_custom_field, april)
  end

end
