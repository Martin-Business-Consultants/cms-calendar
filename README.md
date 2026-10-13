# Calendar

A [Libre Publish](https://github.com/Martin-Business-Consultants/libre-publish) plugin: a content calendar
for the business. What goes out when, on the site (posts and pages, published on their schedule) and on
its social channels, **Facebook Pages, Instagram, LinkedIn (profile and company Pages), X and the Google
Business Profile**, posted directly to each network by the CMS when it's due.

- **The month**, with each item beside it: a social post, a post or page on the site, or a note; its
  posts for each channel and how each went (a link to the post, or why it failed).
- **Ideas** from [Market](https://github.com/Martin-Business-Consultants/cms-market) (open opportunities and
  the posts its AI suggested) and [Google](https://github.com/Martin-Business-Consultants/cms-google)
  (searches the site is close on), taken onto a date in one click.
- **Plan with the AI** ([cms-ai](https://github.com/Martin-Business-Consultants/cms-ai)): a stretch of the
  calendar planned as ideas from Market's plan and angle, the opportunities, the searches to win and what
  Google says people search, around what's planned already.
- **Draft the posts with AI**: each channel's text in its shape and length, from the item, its link and
  the business's plan; read and edit before it goes.
- **A post or page on the site** starts as a draft in the CMS; scheduling the item sets it to publish
  then, and its posts link to it once it's live.
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
    cms get /api/calendar/ideas                         # from Market and Google
    cms post /api/calendar/plans '{"from":"2026-11-01","to":"2026-11-28","per_week":3}'
    cms post /api/calendar/items/7/schedule '{"at":"2026-11-04T10:00:00Z"}'   # calendar:publish: a person's call

Install it into a CMS checkout (core 1.32 or newer; 1.32.3 recommended):

    bin/rails "plugins:install[https://github.com/Martin-Business-Consultants/cms-calendar]"

or add it from Settings › Plugins, then switch it on. Its specs run inside the CMS:

    bin/rspec plugins/calendar/spec

To release, bump `lib/calendar/version.rb`, commit, and tag `vX.Y.Z`.
