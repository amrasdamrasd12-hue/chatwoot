# Eltafouk: tiny build-version endpoint so the dashboard can detect a
# fresh deploy without the agent doing a hard refresh. The frontend
# polls this every minute; when the version flips it shows a banner and
# auto-reloads on the next idle moment. Keeps long-running tabs in sync
# with the bundle that's actually on disk.
class Api::V1::BuildVersionController < ActionController::API
  # No auth — this is just a public version string. Skipping auth keeps
  # the polling cheap even when the session token has rolled.
  def show
    render json: { version: build_version }
  end

  private

  # Use the Vite manifest's mtime as the version token. Asset:precompile
  # rewrites this file on every successful build so its modification
  # time is a perfect "did we deploy" signal. Falls back to 0 in dev
  # where the manifest may not exist yet.
  def build_version
    manifest = Rails.public_path.join('vite/.vite/manifest.json')
    return 0 unless File.exist?(manifest)

    File.mtime(manifest).to_i
  rescue StandardError
    0
  end
end
