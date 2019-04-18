{
  -1 => "d-logo-sketch.png",
  -2 => "d-logo-sketch-small.png",
  -3 => "default-favicon.ico",
  -4 => "default-apple-touch-icon.png"
}.each do |id, filename|
  path = Rails.root.join("public/images/#{filename}")

  Upload.seed do |upload|
    upload.id = id
    upload.user_id = Discourse.system_user.id
    upload.original_filename = filename
    upload.url = "/images/#{filename}"
    upload.filesize = File.size(path)
    upload.extension = File.extname(path)[1..10]
    # Fake an SHA1. We need to have something, so that other parts of the application
    # keep working. But we can't use the real SHA1, in case the seeded file has already
    # been uploaded. Use an underscore to make clash impossible.
    upload.sha1 = "SEED_#{Digest::SHA1.hexdigest("SEEDED_UPLOAD_#{id}")}"[0..Upload::SHA1_LENGTH - 1]
  end
end
