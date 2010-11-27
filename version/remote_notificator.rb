# Simple remote notificator
#
# require 'rubygems'
# require 'net/ssh'
# require 'version/remote_notificator'
#
# recipients = ['kazu.freshout.us', 'kazu@freshout.us']
# repo = 'git@github.com:freshout-dev/breeze.git'
#
# RemoteNotificator.new('root@173.203.95.124', 'empowerkit', recipients, repo).run!
#
class RemoteNotificator

  def initialize(server, project, recipients, repo)
    @server, @project, @recipients = server, project, recipients
    @repo = repo
    @user, @host = @server.split('@')
  end

  def run!
    @recipients.each do |recipient|
      @recipient = recipient
      commands.each do |command|
        Net::SSH.start(@host, @user) do |ssh|
          ssh.exec!(command) { |ch, stream, data| }
        end
      end
    end
  end

  def commands
    [
      reset_file_command,
      prepare_version_command,
      prepare_space_command,
      prepare_commit_messages_command,
      notification_command
    ]
  end

  # ============================================================================
  # COMMANDS
  # ============================================================================

  def reset_file_command
    "echo '' > #{notification_file}"
  end

  def prepare_version_command
    "cat #{version_path} >> #{notification_file}"
  end

  def prepare_commit_messages_command
    "cd #{rails_root} && git log --pretty --format=\"%s%n  - " +
    "(#{resolve_github_path}%h)%n  - %an%n\" -n50  | " +
    "grep -v Merge >> #{notification_file}"
  end

  def notification_command
    "cat #{notification_file} | mail -s '[DEPLOY] #{@project} deployed.' #{@recipient} " +
    "-H 'From: deploy@#{@host};'"
  end

  def prepare_space_command
    "echo \"\n\n\" >> #{notification_file}"
  end

  # ============================================================================
  # PATHS
  # ============================================================================

  # Path for version file
  #
  def version_path
    "/data/#{@project}/current/public/version.txt"
  end

  # Rails root.
  #
  def rails_root
    "/data/#{@project}/current/"
  end

  # Notification file.
  #
  def notification_file
    "/tmp/#{@project}_notification_file.txt"
  end

  # ============================================================================
  # RESOLVE
  # ============================================================================

  def resolve_github_path
    "https://github.com/freshout-dev/#{resolve_repo}/commit/"
  end

  # TODO: remove this responsibility from this class
  def resolve_repo
    @repo.scan(/[a-zA-Z0-9-]+[a-zA-Z0-9]*.git$/).first.gsub(/.git/, '')
  end

end
