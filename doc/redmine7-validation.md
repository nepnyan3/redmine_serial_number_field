# Redmine 7 validation

Validated on 2026-10-27 with Redmine 7.0.2, Rails 8.1.4, Ruby 4.0.9 and PostgreSQL 17.6 in isolated development containers. Only synthetic Redmine fixtures were used; mail delivery was disabled and external runtime egress was blocked. No production system was accessed.

## Passed

From the Redmine application root:

```sh
RAILS_ENV=test bundle exec rake redmine:plugins:test NAME=redmine_serial_number_field
```

Result: **29 runs, 598 assertions, 0 failures, 0 errors, 0 skips** (seed 15392).

Coverage includes issue creation, display, updates, copying, bulk updates, project/tracker moves, calendar and April fiscal-year boundaries, literal prefixes, minimum-width overflow, malformed templates, unauthorized creation, forged serial input, and transaction rollback.

The concurrency regression uses four distinct PostgreSQL backend connections, two shared custom fields, committed fixtures and cross-project issue creation. Each field receives exactly `MCC-0001` through `MCC-0004`. A diagnostic run that removed the field lock in that process failed with four copies of `MCC-0001`, confirming that the regression detects the original race. That diagnostic modification is not part of the implementation.

```sh
RAILS_ENV=development bundle exec rails runner plugins/redmine_serial_number_field/test/reload_smoke.rb
```

Three cycles passed eager loading and verified one current format, issue patch, custom-field patch and hook registration after reloads. The plugin-enabled web server also returned HTTP 200 with the Redmine login form.

## Review and limits

The local review checked that locks join the issue transaction and are acquired in field-id order; allocation bypasses stale query caches; input restoration preserves stored values; and test fixtures/transactions cannot hide concurrent writes. The MIT license and original attribution are retained.

The test harness uses transaction-local PostgreSQL lock timeouts and waits for workers before fixture cleanup. This avoids the connection-cleanup errors seen with a session-level timeout reset after callbacks. A separate Redmine-core diagnostic reproduced stale optimistic-lock versions when saving the same newly created issue object again without reloading, even without this plugin; repeat-save tests reload the issue as a new controller request would.

Actual browser interaction could not be validated: the managed browser route rejected the internal application address with `403 Domain forbidden` before login. HTTP/controller rendering tests passed; they do not prove browser JavaScript behavior. REST transport-specific tests, alternative databases/Ruby versions, large-volume performance, migration of existing duplicates, and production deployment were not performed. GitHub Actions execution is separate from the local results above.

Numbering behavior changes and preserved reuse semantics are documented in README.md and README.en.md. No database migration or automatic renumbering is introduced.
