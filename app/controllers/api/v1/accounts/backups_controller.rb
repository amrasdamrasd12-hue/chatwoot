# Eltafouk: API endpoints to list, trigger, download, and delete database backups
class Api::V1::Accounts::BackupsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    backup_dir = "/home/chatwoot/cw-backups"
    unless Dir.exist?(backup_dir)
      FileUtils.mkdir_p(backup_dir)
      FileUtils.chmod(0755, backup_dir)
    end

    files = Dir.glob(File.join(backup_dir, "chatwoot_production_*.sql.gz")).sort.reverse
    backups = files.map do |file|
      created_at = File.mtime(file)
      # Retention is 7 days, so delete_at is created_at + 7 days
      delete_at = created_at + 7.days
      {
        filename: File.basename(file),
        size: ActiveSupport::NumberHelper.number_to_human_size(File.size(file)),
        created_at: created_at,
        delete_at: delete_at
      }
    end

    disk_stats = get_disk_stats
    cron_interval = get_current_interval

    render json: { backups: backups, disk_stats: disk_stats, cron_interval: cron_interval }
  end

  def create
    backup_script = "/home/chatwoot/cw-backups/backup.sh"
    if File.exist?(backup_script)
      pid = spawn(backup_script)
      Process.detach(pid)
      render json: { message: "Backup started in the background" }, status: :accepted
    else
      render json: { error: "Backup script not found" }, status: :not_found
    end
  end

  def update
    interval = params[:interval].to_s
    unless %w[1 4 8 12 24].include?(interval)
      render json: { error: "Invalid interval" }, status: :bad_request
      return
    end

    cron_expr = case interval
                when "1" then "0 * * * *"
                when "4" then "0 */4 * * *"
                when "8" then "0 */8 * * *"
                when "12" then "0 */12 * * *"
                when "24" then "0 0 * * *"
                end

    # Read current crontab
    current_cron = `crontab -l` rescue ""
    current_cron = current_cron.gsub("\r\n", "\n")

    backup_cron_block = "# BEGIN CHATWOOT BACKUP CRON\n#{cron_expr} /home/chatwoot/cw-backups/backup.sh > /home/chatwoot/cw-backups/backup.log 2>&1\n# END CHATWOOT BACKUP CRON"

    new_cron = if current_cron.include?("# BEGIN CHATWOOT BACKUP CRON")
                 current_cron.sub(/# BEGIN CHATWOOT BACKUP CRON.*?# END CHATWOOT BACKUP CRON/m, backup_cron_block)
               else
                 [current_cron.strip, backup_cron_block].reject(&:empty?).join("\n") + "\n"
               end

    IO.popen("crontab -", "w") do |io|
      io.write(new_cron)
    end

    if $?.success?
      render json: { message: "Backup interval updated successfully", cron_interval: interval }
    else
      render json: { error: "Failed to update crontab" }, status: :internal_server_error
    end
  end

  def show
    filename = params[:id]
    if filename.match?(/\Achatwoot_production_[a-zA-Z0-9_\-]+\.sql\.gz\z/)
      file_path = File.join("/home/chatwoot/cw-backups", filename)
      if File.exist?(file_path)
        log_backup_action('download', filename)
        send_file file_path, type: 'application/gzip', disposition: 'attachment', filename: filename
      else
        render json: { error: "File not found" }, status: :not_found
      end
    else
      render json: { error: "Invalid filename" }, status: :bad_request
    end
  end

  def destroy
    filename = params[:id]
    if filename.match?(/\Achatwoot_production_[a-zA-Z0-9_\-]+\.sql\.gz\z/)
      file_path = File.join("/home/chatwoot/cw-backups", filename)
      if File.exist?(file_path)
        log_backup_action('delete', filename)
        File.delete(file_path)
        render json: { message: "Backup deleted successfully" }
      else
        render json: { error: "File not found" }, status: :not_found
      end
    else
      render json: { error: "Invalid filename" }, status: :bad_request
    end
  end

  private

  # Backups are an INSTANCE-GLOBAL resource (full production DB dumps that span
  # every account), so they must be gated on instance super-admin — not on
  # per-account `administrator`, which any account's admin would satisfy.
  # SuperAdmin < User (STI on the users table), so the access-token owner is a
  # SuperAdmin row iff the signed-in user is an instance admin.
  def check_authorization
    raise Pundit::NotAuthorizedError unless Current.user.is_a?(SuperAdmin)
  end

  # Audit trail for sensitive backup operations (who/what/when/where), so a DB
  # dump leaving the server is always traceable.
  def log_backup_action(action, filename)
    Rails.logger.info(
      "[backups] action=#{action} filename=#{filename} " \
      "user_id=#{Current.user&.id} email=#{Current.user&.email} ip=#{request.remote_ip}"
    )
  end

  def get_current_interval
    output = `crontab -l` rescue ""
    if output =~ /# BEGIN CHATWOOT BACKUP CRON\n([^\n]+)\n# END CHATWOOT BACKUP CRON/m
      cron_line = $1.strip
      if cron_line.start_with?("0 * * * *")
        return "1"
      elsif cron_line.start_with?("0 */4 * * *")
        return "4"
      elsif cron_line.start_with?("0 */8 * * *")
        return "8"
      elsif cron_line.start_with?("0 */12 * * *")
        return "12"
      elsif cron_line.start_with?("0 0 * * *")
        return "24"
      end
    end
    "4" # Default fallback
  end

  def get_disk_stats
    output = `df -h /` rescue ""
    lines = output.split("\n")
    if lines.length >= 2
      parts = lines[1].split(/\s+/)
      if parts.length >= 5
        return {
          total: parts[1],
          used: parts[2],
          free: parts[3],
          percent: parts[4].delete('%').to_i
        }
      end
    end
    { total: "N/A", used: "N/A", free: "N/A", percent: 0 }
  end
end
