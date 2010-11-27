require "bundler"
Bundler.setup(:default, :test)
require 'net/ssh'
require 'net/sftp'
require 'json'
require 'version/version'
require 'version/remote_notificator'
require 'version/deployment_lock'
require 'rspec/core/rake_task'

REMOTE_CHEF_PATH = "/etc/chef" # Where to find upstream cookbooks

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = FileList['spec/*_spec.rb']
end

task :default  => :spec

desc 'Create a new recipe.

Usage:

  $ rake new[my_cookname]

Output:

    -  mkdir -p cookbooks/my_cookname/templates
    -  mkdir -p cookbooks/my_cookname/recipes
    -  mkdir -p cookbooks/my_cookname/attributes
    -  touch cookbooks/my_cookname/recipes/default.rb
    -  touch cookbooks/my_cookname/attributes/default.rb

'
task :new, :name do |task, hash|
  name = hash[:name]; commands = []
  commands << "mkdir -p cookbooks/#{name}/templates"
  commands << "mkdir -p cookbooks/#{name}/recipes"
  commands << "mkdir -p cookbooks/#{name}/attributes"
  commands << "touch cookbooks/#{name}/recipes/default.rb"
  commands << "touch cookbooks/#{name}/attributes/default.rb"
  commands.each do |cmd|
    puts "  -  #{cmd}"; `#{cmd}`
  end
end

desc "Test your cookbooks and config files for syntax errors"
task :test do
  Dir[ File.join(File.dirname(__FILE__), "**", "*.rb") ].each do |recipe|
    sh %{ruby -c #{recipe}} do |ok, res|
      raise "Syntax error in #{recipe}" if not ok
    end
  end
end

desc "Create dna from ruby file"
task :create_dna  do
  check_dna_env_variable

  if !ENV["instance_role"]
    puts "You need to specify an instance_role 'rake [ create_dna | upload | cook ] instance_role=solo'"
    exit 1
  end
  require dna_file
  file = open(File.dirname(__FILE__) + "/tmp/json/#{ENV["dna"]}_dna.json", "w")
  file.write(@dna.merge({:instance_role => ENV['instance_role']}).to_json)
  file.close
end

desc "Upload the latest copy of your cookbooks to remote server"
task :upload => [:create_dna] do
  check_server_env_variable
  check_deployment_lock
  banner 'Uploading your cookbooks.'
  sh "rsync -rlP --delete --exclude '.*' #{File.dirname(__FILE__)}/ #{ENV['server']}:#{REMOTE_CHEF_PATH}"
  deployment_lock.remove!
end

desc 'Run chef solo on the server'
task :cook => [:upload] do
  require dna_file
  check_deployment_lock
  banner 'Running chef solo on remote server'
  sh "ssh #{ENV['server']} \"chef-solo -l debug -c #{REMOTE_CHEF_PATH}/config/solo.rb -j #{REMOTE_CHEF_PATH}/tmp/json/#{ENV["dna"]}_dna.json \""
  @dna[:applications].each do |application|
    next unless ['solo', 'app_master'].include?(ENV["instance_role"])
    setup_remote_version_file application[:name], application[:revision]
    send_deployed_notification application[:name], application[:repo]
  end
  deployment_lock.remove!
end

desc 'bootstrap an instance with some chef'
task :bootstrap do
  banner 'Server setup.'
  Net::SFTP.start(host, user) do |sftp|
    sftp.upload!("#{File.dirname(__FILE__)}/chef_bootstrap.rb", "/tmp/chef_bootstrap.rb")
  end

  Net::SSH.start(host, user) do |ssh|
    ssh.exec!("aptitude -y install ruby; ruby /tmp/chef_bootstrap.rb") do |ch, stream, data|
      if stream == :stderr
        puts "ERROR: #{data}"
      else
        puts data
      end
    end
  end
end

desc 'upload ssh key'
task :upload_ssh_key do
  banner 'Installing ssh keys on remote server.'
  local_key = open(key) { |f| f.read }
  stdout = ""
  Net::SSH.start(host, user, :password => password) do |ssh|
    if remote_ssh_directory_exists?(ssh)
      stdout << "- Dependency: SSH folder exists [yes]\n"
      # check if the authorized_keys file exists
      if remote_authorized_key_file_exists?(ssh)
        stdout << "- Dependency: authorized_keys exists [yes]\n"
      else
        stdout << "- Dependency: authorized_keys exists [no]\n"
        create_authorized_keys_file(ssh, stdout)
      end
    else
      stdout << "- Dependency: SSH folder exists [no]\n"
      ssh.exec!("mkdir ~/.ssh")
      stdout << "- Created .ssh folder\n"
      create_authorized_keys_file(ssh, stdout)
    end

    ssh.exec!("echo \"#{local_key}\" >> ~/.ssh/authorized_keys")
    stdout << "- Added key to file [yes]"
  end
  puts stdout
end

# ==============================================================================
# SSH KEY SETUP
# ==============================================================================

# Determines whether an ~/.ssh directory exists on the client side
def remote_ssh_directory_exists?(connection)
  output = ""
  cmd_check_ssh = "test -e ~/.ssh && echo 1"
  connection.exec!(cmd_check_ssh) do |ch, stream, data|
    output << data if stream == :stdout
  end
  output.chomp == "1"
end

def remote_authorized_key_file_exists?(connection)
  output = ""
  cmd_check_keyfile = "test -e ~/.ssh/authorized_keys && echo 1"
  connection.exec!(cmd_check_keyfile) do |ch, stream, data|
    output << data if stream == :stdout
  end
  output.chomp == "1"
end

# Creats an authorized key file (.ssh/authorized_keys) on the remote host
def create_authorized_keys_file(connection, stdout)
  connection.exec!("touch ~/.ssh/authorized_keys")
  stdout << "- Created ~/.ssh/authorized_keys\n"
end

# ==============================================================================
# DNA LOADING
# ==============================================================================

def dna_filepath
  @dna_filepath ||=
  File.join(File.dirname(__FILE__), 'config', "#{ENV["dna"]}_dna.rb")
end

# TODO: check why we need to call *to_s*
def dna_file
  raise "File not found: #{dna_filepath}" unless File.exists? dna_filepath
  dna_filepath.to_s
end

# ==============================================================================
# OUTPUT
# ==============================================================================

def banner(str)
  puts ' ' * 80
  puts '** ' + str
  puts '*' * 80
end

def done
  puts 'Done!'
end

# ==============================================================================
# INSTALL A REMOTE VERSION.TXT FILE
# ==============================================================================

def setup_remote_version_file project, revision
  check_server_and_dna_variables
  banner 'Setting up version file.'
  SetupRemoteVersion.new(server, "/data/#{project}/current", revision).install!
  done
end

# ==============================================================================
# SEND EMAIL NOTIFICATIONS WHEN A PROJECT IS DEPLOYED!
# ==============================================================================

def send_deployed_notification project, repo
  check_server_and_dna_variables
  return unless @dna[:deployment][:active]
  banner 'Sending notifications. '
  puts recipients.inspect
  RemoteNotificator.new(server, project, recipients, repo).run!
  done
end

# Mail recipients
#
# NOTE: Only use when @dna is loaded
#
def recipients
  @dna[:deployment][:recipients]
end

# ==============================================================================
# ENVIRONMENT ARGUMENTS & THEIR VALIDATIONS
# ==============================================================================

def check_dna_env_variable
  if !ENV["dna"]
    puts "You need to specify a dna file 'rake [ create_dna | upload | cook ] dna=mongodb'"
    exit 1
  end
end

def check_server_env_variable
  if !ENV["server"]
    puts "You need to specify a server 'rake cook server=whatever.com'"
    exit 1
  end
end

def check_server_and_dna_variables
  check_server_env_variable
  check_dna_env_variable
end

def check_key_and_password
  if !ENV["key"] || !ENV["pass"]
    puts "You need to specify the full path of your public key file and pass 'rake upload_ssh_key server=whatever.com pass=secret key=/Users/foo/.ssh/id_rsa-pub'"
    exit 1
  end
end

def server
  ENV['server']
end

def key
  check_key_and_password
  ENV['key']
end

def password
  check_key_and_password
  ENV['pass']
end

def user
  check_server_env_variable
  ENV['server'].match(/([\w\.\-\+]+)@([\S]+)/)[1]
end

def host
  check_server_env_variable
  ENV['server'].match(/([\w\.\-\+]+)@([\S]+)/)[2]
end

# ==============================================================================
# DEPLOYMENT LOCKING
# ==============================================================================

def deployment_lock
  @deployment_lock ||= get_or_create_deployment_lock
end

def get_or_create_deployment_lock
  dl      = DeploymentLock.new
  dl.path = '/tmp/deployment_lock.txt'
  dl.user = user
  dl.host = host
  dl
end

def check_deployment_lock
  banner 'Checking deployment lock'
  if deployment_lock.exists?
    abort "Stopped because [#{deployment_lock.read}] is currently deploying!"
  else
    deployment_lock.create!
  end
end

