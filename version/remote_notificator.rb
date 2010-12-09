
require 'rubygems'
require 'net/ssh'
require 'fileutils'
require 'net/sftp'

# Simple remote notificator
#
# require 'version/remote_notificator'
#
# recipients = ['kazu.freshout.us', 'kazu@freshout.us']
# repo = 'git@github.com:freshout-dev/breeze.git'
#
# RemoteNotificator.new('root@192.168.2.33', 'empowerkit', recipients, repo, 'ek_dev').run!
#
class RemoteNotificator

  attr_accessor :local_file

  def initialize(server, project, recipients, repo, env)
    @server, @project, @recipients = server, project, recipients
    @repo, @env = repo, env
    @local_file = '/tmp/remote_commands.sh'
    @user, @host = @server.split('@')
  end

  def run!
    File.open(local_file, 'w+') {}
    File.open(local_file, 'a+') do |file|
      file.puts reset_file_command
      file.puts prepare_version_command
      file.puts prepare_space_command
      file.puts prepare_commit_messages_command
      @recipients.each { |email| file.puts notification_command(email) }
    end
    Net::SFTP.start(@host, @user) do |sftp|
      sftp.upload!(local_file, '/tmp/notify.sh')
    end
    Net::SSH.start(@host, @user) do |ssh|
      command = 'chmod +x /tmp/notify.sh && /tmp/notify.sh'
      ssh.exec!(command) { |ch, stream, data| }
    end
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
    "(#{resolve_github_path}%h)%n  - %an%n\" -n50  >> #{notification_file}"
  end

  def notification_command recipient
    "cat #{notification_file} | mail -s '[DEPLOYED] #{@project} #{@env}.' #{recipient} " +
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
