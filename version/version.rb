
require 'rubygems'
require 'deploy_version'

class SetupRemoteVersion

  def initialize server, source_path, r, temp_file = '/tmp/deployed_version.yml'
    @server, @source_path, @temp_file = server, source_path, temp_file
    user, host = @server.split('@')
    @version = Deploy::Version.new
    @version.deployed_by = `whoami`.chomp
    @version.add :ip, host
    @version.add :branch, r
    self
  end

  def install!
    user, host = @server.split('@')

    Net::SSH.start(host, user) do |ssh|
      ssh.exec!(version_cmd) do |ch, stream, data|
        if stream == :stdout
          @version.current_version = data.chomp.gsub(/\n|\|/, '')
        end
      end
    end

    @version.store_to_file(@temp_file)

    Net::SFTP.start(host, user) do |sftp|
      sftp.upload!(@temp_file, @source_path + '/public/version.txt')
    end
  end

  protected

  def version_cmd
    "cd #{@source_path} && git log -n1 --pretty='%H'"
  end

end

