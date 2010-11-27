
require 'rubygems'
require 'net/ssh'

class DeploymentLock

  attr_accessor :user, :host, :path

  def can_execute?
    raise 'No user given' if @user.nil?
    raise 'No host given' if @host.nil?
    raise 'No path given' if @path.nil?
  end

  def remove!
    can_execute?
    execute "touch #{path}"
    execute "rm #{path}"
  end

  def create!
    can_execute?
    execute "touch #{path}"
    execute "rm #{path}"
    execute "echo '#{me}' > #{path}"
  end

  def exists?
    can_execute?
    execute("ls #{path}") == path + "\n"
  end

  def read
    can_execute?
    execute("cat #{path}").chomp
  end

  protected

  def execute command
    ret = ''
    Net::SSH.start(@host, @user) do |ssh|
      ssh.exec!(command) do |ch, stream, data|
        ret = data if stream == :stdout
      end
    end
    ret
  end

  def me
    `whoami`.chomp
  end

end
