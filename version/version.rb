
require 'rubygems'
require 'deploy_version'

class SetupRemoteVersion

  attr_accessor :temp_file

  def temp_file
    @temp_file ||= '/tmp/deployed_version.yml'
  end

  def initialize server, source_path, branch, env
    @server, @source_path = server, source_path
    @user, @host = @server.split('@')
    @version = Deploy::Version.new
    @version.deployed_by = `whoami`.chomp
    @version.add :ip, @host
    @version.add :branch, branch
    @version.add :environment, env
    self
  end

  def install!
    @version.current_version = version
    @version.store_to_file(temp_file)
    Net::SFTP.start(@host, @user) do |sftp|
      sftp.upload!(temp_file, @source_path + '/public/version.txt')
    end
  end

  protected

  def version_command
    "cd #{@source_path} && git log -n1 --pretty='%H'"
  end


  def version
    ret_val = nil
    Net::SSH.start(@host, @user) do |ssh|
      ssh.exec!(version_command) do |ch, stream, data|
        ret_val = data.chomp.gsub(/\n|\|/, '') if (stream == :stdout)
      end
    end
    ret_val
  end

end
