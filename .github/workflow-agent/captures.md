# Screenshots and videos

Use a temporary system spec with representative data and the existing page objects. Require the HiDPI helper:

```ruby
require_relative "../../.github/workflow-agent/hidpi"
```

Run the spec with `dev discourse_dev bin/rspec spec/system/<capture>_spec.rb` and a shell timeout of 600 seconds. Build frontend assets with `dev discourse_dev pnpm build` when they are missing or stale.

- **Screenshots:** save a PNG under `tmp/agent-screenshots/` with `page.save_screenshot`.
- **Videos:** add `video: true` to the spec. Enable animations with `RSpec.configure { |config| config.before(:suite) { Capybara.disable_animation = false } }`. After the spec finishes, use `tmp/capybara/*-screenrecord.webm`.

Upload the file directly with `upload_image` using its workspace path under `/src` (maximum 10 MiB). Embed screenshots as `![Description](URL)`; put video URLs on their own line.

For before/after comparisons, use the same data, viewport, and interactions on both revisions. Save each recording before the next run overwrites it, label the results, and restore the working revision.

Remove the temporary spec afterward. Do not commit captures or capture-only changes.
