---
name: discourse-response-screenshots
description: Capture HiDPI screenshots and videos of Discourse UI with a temporary system spec, and include them in the workflow bot's GitHub response. Use when screenshots or videos are requested or help demonstrate a UI change.
---

# Screenshots and videos in bot responses

Use a temporary system spec to create representative data and reach the desired UI. Run only that spec in `discourse_dev`; the spec starts its own test server, so no separate development server is needed.

1. Read a nearby system spec and reuse its fabricators, sign-in helpers, and page objects. Create a uniquely named `spec/system/agent_screenshot_<feature>_spec.rb`. Use synthetic data suitable for a public screenshot.
2. Always capture screenshots and videos in HiDPI mode. Require `../../.skills/discourse-response-screenshots/scripts/hidpi` from the temporary system spec (see the example below). It uses a 2× device scale and a video size of twice the CSS viewport dimensions, avoiding Playwright’s default video downscaling. Keep the CSS viewport at the desired desktop/mobile size; enlarging it changes the layout rather than the pixel density.
3. Navigate to the requested state and wait for it with a Capybara expectation. Save a PNG under `tmp/agent-screenshots/` using an absolute path. Capture just the requested state; run theme/device variants only when relevant.
4. Run through the workspace shell with `timeout_seconds: 600`:

   ```sh
   dev discourse_dev bin/rspec spec/system/agent_screenshot_<feature>_spec.rb
   ```

   Follow the environment description for missing dependencies and test-database preparation. System specs also need frontend assets: run `dev discourse_dev pnpm build` when missing or stale after frontend edits. If Chromium is missing, run `dev discourse_dev pnpm exec playwright install chromium`; if it reports missing system libraries, use `dev discourse_dev pnpm exec playwright install-deps chromium`. Set `LOAD_PLUGINS=1` when the captured UI depends on plugins. Avoid installing or rebuilding things already available.
5. Confirm the spec passed and the PNG was created. The workspace currently has no image-viewing tool, so use assertions immediately before capture to verify the intended UI has loaded; do not claim a visual inspection. Call `upload_image` with the workspace path, such as `/src/tmp/agent-screenshots/topic.png`. The tool accepts PNG, MP4, and WebM files up to 10 MiB and returns a GitHub URL; it handles credentials outside the sandbox.
6. Remove the temporary spec and any temporary helpers you created. Do not commit captures or capture-only changes; stage the intended product files explicitly. Captures can remain in ignored `tmp/` until the run ends.
7. Include `![Short description](returned URL)` in `finish.reply`, or a relevant `line_comment` body. Keep the surrounding text brief. Local paths and Actions artifact links will not embed the image. If capture or upload fails, explain the limitation without inventing a URL.

Adapt this minimal example to the feature:

```ruby
# frozen_string_literal: true

require_relative "../../.skills/discourse-response-screenshots/scripts/hidpi"

RSpec.describe "Topic screenshot", type: :system do
  fab!(:user)
  fab!(:post) { Fabricate(:post, raw: "A sample post for the screenshot.") }

  let(:topic_page) { PageObjects::Pages::Topic.new }

  it "shows the topic to the signed-in user" do
    sign_in(user)
    topic_page.visit_topic(post.topic)
    expect(topic_page).to have_post_content(post_number: 1, content: post.raw)

    directory = Rails.root.join("tmp/agent-screenshots")
    FileUtils.mkdir_p(directory)
    page.save_screenshot(directory.join("topic.png").to_s)
  end
end
```

For a before/after comparison, use the same data, viewport, and UI state on both revisions. Label the captures clearly and restore the working revision before finishing.

For video captures, add `video: true` to the example and wait for the spec to finish before using the resulting `tmp/capybara/*-screenrecord.webm`. Enable animations for demonstrations with `RSpec.configure { |config| config.before(:suite) { Capybara.disable_animation = false } }`. Keep the original resolution when trimming or converting the recording. Upload the WebM directly with `upload_image`, or convert to H.264 MP4 with `ffmpeg -i input.webm -c:v libx264 -crf 23 -pix_fmt yuv420p -movflags +faststart output.mp4` if needed. Keep each file under 10 MiB by trimming idle time or increasing compression, without reducing the resolution. Put each returned video URL on its own line in `finish.reply`, with a short Before/After label above it; do not use Markdown image syntax for videos.

Verify `window.devicePixelRatio` is `2` in the capture spec. A 390×664 CSS-pixel mobile viewport should produce a 780×1328 PNG and video; check video dimensions with `ffprobe` when available.
