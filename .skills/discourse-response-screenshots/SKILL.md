---
name: discourse-response-screenshots
description: Capture Discourse UI with a temporary system spec and include screenshots in the workflow bot's GitHub response. Use when screenshots are requested or help demonstrate a UI change.
---

# Screenshots in bot responses

Use a temporary system spec to create representative data and reach the desired UI. Run only that spec in `discourse_dev`; the spec starts its own test server, so no separate development server is needed.

1. Read a nearby system spec and reuse its fabricators, sign-in helpers, and page objects. Create a uniquely named `spec/system/agent_screenshot_<feature>_spec.rb`. Use synthetic data suitable for a public screenshot.
2. Navigate to the requested state and wait for it with a Capybara expectation. Save a PNG under `tmp/agent-screenshots/` using an absolute path. Capture just the requested state; run theme/device variants only when relevant.
3. Run through the workspace shell with `timeout_seconds: 600`:

   ```sh
   dev discourse_dev bin/rspec spec/system/agent_screenshot_<feature>_spec.rb
   ```

   Follow the environment description for missing dependencies and test-database preparation. System specs also need frontend assets: run `dev discourse_dev pnpm build` when missing or stale after frontend edits. If Chromium is missing, run `dev discourse_dev pnpm exec playwright install chromium`; if it reports missing system libraries, use `dev discourse_dev pnpm exec playwright install-deps chromium`. Set `LOAD_PLUGINS=1` when the captured UI depends on plugins. Avoid installing or rebuilding things already available.
4. Confirm the spec passed and the PNG was created. The workspace currently has no image-viewing tool, so use assertions immediately before capture to verify the intended UI has loaded; do not claim a visual inspection. Call `upload_image` with the workspace path, such as `/src/tmp/agent-screenshots/topic.png`. The tool accepts PNGs up to 10 MiB and returns a GitHub URL; it handles credentials outside the sandbox.
5. Remove the temporary spec and any temporary helpers you created. Do not commit screenshots or capture-only changes; stage the intended product files explicitly. PNGs can remain in ignored `tmp/` until the run ends.
6. Include `![Short description](returned URL)` in `finish.reply`, or a relevant `line_comment` body. Keep the surrounding text brief. Local paths and Actions artifact links will not embed the image. If capture or upload fails, explain the limitation without inventing a URL.

Adapt this minimal example to the feature:

```ruby
# frozen_string_literal: true

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

For a before/after comparison, use the same data, viewport, and UI state on both revisions. Label the images clearly and restore the working revision before finishing.
