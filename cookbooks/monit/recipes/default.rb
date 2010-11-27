def should_deploy?
  proper_enviroment? && monit
end

def proper_enviroment?
  ['app_master', 'solo', 'app_slave', 'db_master'].include?(node[:instance_role])
end

def create_monit_directory
  directory '/etc/monit.d' do
    mode 0755
    recursive true
  end
end

def upload_monit_control_file monit
  template '/etc/monit/monitrc' do
    mode 0700
    source 'monit.rc.erb'
    action :create
    variables(:monit => monit, :hostname => node[:hostname])
  end
end

def upload_monit_status_notifier monit
  template '/tmp/send_monitoring_status_by_mail' do
    mode 0700
    source 'send_monitoring_status_by_mail.bash.erb'
    action :create
    variables(:monit => monit)
  end
end

def activate_monit_service
  template '/etc/default/monit' do
    mode 0700
    source 'monit.erb'
    action :create
  end
end

# NOTE: Monit wont start if it doesn't find any files.
def generate_empty_global_config
  execute 'generate_empty_global_config' do
    command 'touch /etc/init.d/empty'
  end
end

def monit
  @monit ||= node[:monit]
end

def execute!
  return puts 'Skiping monit setup.' unless should_deploy?
  package 'monit'

  service "monit" do
    action :stop
  end

  create_monit_directory
  activate_monit_service
  upload_monit_control_file monit
  upload_monit_status_notifier monit
  generate_empty_global_config

  service "monit" do
    action :start
  end
end

execute!

