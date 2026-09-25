# frozen_string_literal: true

ENV["CHROME_DISABLE_FORCE_DEVICE_SCALE_FACTOR"] = "1"

module ResponseCaptureHiDpi
  def initialize(app, **options)
    viewport = options.fetch(:viewport)
    super(
      app,
      **options,
      deviceScaleFactor: 2,
      # Chromium also needs a HiDPI compositor for full-resolution video frames.
      args: [*options.fetch(:args), "--force-device-scale-factor=2"],
      record_video_size: {
        width: viewport.fetch(:width) * 2,
        height: viewport.fetch(:height) * 2,
      },
    )
  end
end

Capybara::Playwright::Driver.prepend(ResponseCaptureHiDpi)
