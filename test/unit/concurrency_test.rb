require File.expand_path('../../test_helper', __FILE__)
require 'timeout'

class SerialNumberField::ConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  fixtures :all

  def setup
    User.current = nil
    @field = create_default_serial_number_field
    @second_field = create_for_all_serial_number_field
  end

  def teardown
    Issue.where("subject LIKE ?", 'Serial concurrency %').find_each(&:destroy!)
    @field&.destroy!
    @second_field&.destroy!
    User.current = nil
  end

  def test_concurrent_creates_share_a_unique_sequence_across_projects
    # Separate checked-out connections and committed transactions are essential:
    # transactional fixtures would hide the field from the worker connections.
    ready = Queue.new
    start = Queue.new
    format = @field.format
    generate = format.method(:generate_value)
    format.define_singleton_method(:generate_value) do |field, issue|
      value = generate.call(field, issue)
      sleep 0.05 # Widen the read/write race that used to allocate duplicates.
      value
    end
    threads = 4.times.map do |index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          User.current = User.find(2)
          ready << connection.raw_connection.backend_pid
          start.pop
          Issue.transaction do
            connection.execute("SET LOCAL lock_timeout = '5s'")
            Issue.create!(project_id: index.even? ? 1 : 2, tracker_id: 1,
                          author_id: 2, subject: "Serial concurrency #{index}").id
          end
        ensure
          User.current = nil
        end
      rescue => error
        error
      end
    end
    ids = Timeout.timeout(15) do
      connection_ids = 4.times.map { ready.pop }
      assert_equal 4, connection_ids.uniq.size, "Workers must use separate PostgreSQL connections"
      4.times { start << true }
      results = threads.map(&:value)
      errors = results.grep(Exception)
      assert_empty errors, errors.map(&:full_message).join("\n")
      results
    end
    [@field, @second_field].each do |field|
      numbers = CustomValue.where(custom_field_id: field.id, customized_id: ids).pluck(:value)
      assert_equal %w(MCC-0001 MCC-0002 MCC-0003 MCC-0004), numbers.sort
    end
  ensure
    4.times { start << true } if start
    threads&.each { |thread| thread.join(10) }
    format&.singleton_class&.remove_method(:generate_value)
  end
end
