# Calendar

A [Libre Publish](https://github.com/Martin-Business-Consultants/libre-publish) plugin: a content calendar
for the business. What goes out when, on the site (posts and pages, published on their schedule) and on
its social channels, **Facebook Pages, Instagram, LinkedIn (profile and company Pages), X and the Google
Business Profile**, posted directly to each network by the CMS when it's due.

## How it works

**Ideas → Write → Schedule → Published**, shown across the top of the Calendar and Ideas, with how many
are at each step.

1. **Ideas** come from [Market](https://github.com/Martin-Business-Consultants/cms-market) and
   [Google](https://github.com/Martin-Business-Consultants/cms-google), the most timely first: searches
   coming into season (a tracked search, or one worth writing about, that peaks within a few months,
   dated two months before its peak so the post has time to rank), the plan's opportunities (with the
   goal each serves), searches worth writing about (with searches a month and difficulty), the posts
   Market's AI suggested, and searches Google says the site is close on. Take one onto the calendar in a
   click, on its suggested date or another. Or **plan with the AI**
   ([cms-ai](https://github.com/Martin-Business-Consultants/cms-ai)): a stretch of the calendar from
   Market's plan and goals, these ideas (seasonal ones before their date) and what Google says people
   search, around what's planned already.
2. **Write**: open an item beside the month; it says what's next. A post or page on the site starts as a
   draft in the CMS; a social post gets each channel's text, written by hand or drafted by the AI.
3. **Schedule**: give it a time. A post or page on the site publishes then; its social posts go out when
   it's due, and link to it once it's live.
4. **Published**: each channel's post links to where it went, or says why it didn't.

- **Scheduling is publishing**: it takes `calendar:publish` (editors have it); authors and the Agent role
  write and draft (`calendar:read`, `calendar:write`), and a person schedules. Each item is claimed before
  it's sent, so it never goes out twice; a channel that fails keeps why, and the rest still go.

## Connecting the networks (Settings › Calendar)

Each network posts through a developer app of your own; Settings › Calendar shows the redirect URI to add
to each.

- **Meta** ([developers.facebook.com](https://developers.facebook.com/apps)): a Business app with Facebook Login
  for Business. Connecting lists every Page the person manages and each Page's Instagram professional
  account. Posting needs `pages_manage_posts` and `instagram_content_publish`, granted by Meta's app review
  (the app's own admins can post before review). Instagram posts need an image with a public address.
- **LinkedIn** ([linkedin.com/developers](https://www.linkedin.com/developers/apps)): add *Share on LinkedIn*
  and *Sign In with LinkedIn using OpenID Connect* for the person's profile; company Pages need the
  *Community Management API*, which LinkedIn grants on request. Tokens last 60 days.
- **X** ([developer.x.com](https://developer.x.com/en/portal/dashboard)): OAuth 2.0, Web App (confidential
  client), read and write. Posting takes a plan with write access to the X API.
- **Google Business Profile**: through Settings › Google (cms-google), once its Business Profile is connected.

Tokens are encrypted and never read back.

## For agents and a local harness

    cms get "/api/calendar/items?from=2026-11-01&to=2026-11-30"
    cms post /api/calendar/items '{"item":{"title":"…","kind":"social","body":"…","channel_ids":[1,2]}}'
    cms post /api/calendar/items/7/draft '{}'          # the AI writes each channel's post
    cms get /api/calendar/ideas                         # from Market and Google, timely first; each with facts and a suggested date (on)
    cms post /api/calendar/plans '{"from":"2026-11-01","to":"2026-11-28","per_week":3}'
    cms post /api/calendar/items/7/schedule '{"at":"2026-11-04T10:00:00Z"}'   # calendar:publish: a person's call

Install it into a CMS checkout (core 1.32 or newer; 1.32.3 recommended):

    bin/rails "plugins:install[https://github.com/Martin-Business-Consultants/cms-calendar]"

or add it from Settings › Plugins, then switch it on. Its specs run inside the CMS:

    bin/rspec plugins/calendar/spec

To release, bump `lib/calendar/version.rb`, commit, and tag `vX.Y.Z`.
