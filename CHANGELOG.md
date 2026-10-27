## 4.0.0 (unreleased)

- Target Redmine 7; verified on Redmine 7.0.2, Rails 8.1.4, Ruby 4.0.9 and PostgreSQL 17.6.
- Align namespaced files and initialization with Zeitwerk; support eager loading and development reloads.
- Replace removed Active Record APIs and preserve specific template validation errors.
- Ignore submitted serial values and keep allocated numbers visible immediately after saving.
- Serialize allocation per custom field within the issue transaction, including cross-project concurrent writes.
- Compare the final counter numerically and allow it to grow beyond its minimum width; match prefixes literally and preserve fixed digits.
- Calculate the April fiscal-year boundary without the fiscali dependency or global fiscal-zone state.
- Add regression, authorization, rollback, concurrency and reload checks; update CI for Redmine 7.
- Keep the maximum-existing-value policy: deletion/moving can still allow reuse; existing duplicates are not migrated.

## 3.0.0

- Added ISO format #8 (@rambowm)
- Dropped Redmine 4.0 support
- Redmine 4.1 support
- Fixed automatic serial number when copying issue
  - チケットコピー時に自動採番されない #6 (@subaru019)
  - [Review comments for this plugin on redmine.org](https://www.redmine.org/plugins/redmine_serial_number_field) (Jorge Garcia, Quan VN, qn wang)

## 2.0.0

- Support Redmine 4.0 (@nanego)
- Support French locale (@nanego)
- Drop support Redmine version 3.4 lower (@maeda-m)

## 1.0.0

- Changed the range to count sequential numbers from project unit to whole sharing as custom field unit #4 (@neocosmic2)

## 0.9.0

- Support Turkish locale #3 (@atopcu)
- Allow only sequence numbers #2 (@y-arai)
- Drop support Redmine versions 2.6 and 3.1 (@maeda-m)
