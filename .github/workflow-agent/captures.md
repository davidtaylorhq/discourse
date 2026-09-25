# Screenshots and videos

Use a temporary system spec with representative data and the existing page objects. Require the HiDPI helper:

```ruby
require_relative "../../.github/workflow-agent/hidpi"
```

Prepare dependencies and the test database as described by the `discourse_dev` environment. Before the first capture, install Chromium **and its system libraries** inside that environment:

```sh
dev discourse_dev pnpm exec playwright install --with-deps --no-shell chromium
```

`pnpm playwright-install` installs the browser only, leaving the required system libraries missing in a fresh container.

Build frontend assets with `dev discourse_dev pnpm build` when missing or stale, then run `dev discourse_dev bin/rspec spec/system/<capture>_spec.rb` with a shell timeout of 600 seconds. Keep command failures visible: use `bash -e -o pipefail -c` when combining setup commands or piping spec output.

- **Screenshots:** save a PNG under `tmp/agent-screenshots/` with `page.save_screenshot`.
- **Videos:** add `video: true` to the spec. Enable animations with `RSpec.configure { |config| config.before(:suite) { Capybara.disable_animation = false } }`. After the spec finishes, use `tmp/capybara/*-screenrecord.webm`.

Upload the file directly with `upload_image` using its workspace path under `/src` (maximum 10 MiB). Embed screenshots as `![Description](URL)`; put video URLs on their own line.

For before/after comparisons, use the same data, viewport, and interactions on both revisions. Save each recording before the next run overwrites it, label the results, and restore the working revision.

Remove the temporary spec afterward. Do not commit captures or capture-only changes.
