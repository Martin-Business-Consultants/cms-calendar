# Calendar, a Libre Publish plugin — guide for AI agents

A Rails engine loaded into a CMS install from `plugins/calendar`. Read the core's `docs/plugins.md` and
`STYLE.md` first.

- `Calendar::Item` is one thing on the calendar; `Calendar::Delivery` is it going to one
  `Calendar::Channel`. `Item.dispatch_due` (every minute, `Calendar::DispatchJob`) claims each due item
  (scheduled → sending) before sending, so nothing posts twice.
- Each network is a plain object under `app/models/calendar/networks/` (`authorize_url`, `connect`,
  `publish`, `refresh!`), over Net::HTTP; `Calendar::Networks::Base.transport` stands in for the network
  in specs (`spec/support/calendar_helpers.rb`). The Business Profile goes through the Google plugin.
- The AI (`Calendar::Drafter`, `Calendar::Planner`) is told the business through `Calendar::Context`:
  the brand brief, Market's plan and angle, Google's searches. Both run in jobs and never raise.
- Scheduling takes `calendar:publish`; never schedule from an agent's token.

Check: `bin/rspec plugins/calendar/spec`, `bin/rubocop plugins/calendar`, `bundle exec herb lint plugins/calendar/app/views`.
