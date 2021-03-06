#
# Cookbook Name:: cron
# Recipe:: default
#
if ['app_master', 'solo'].include?(node[:instance_role])
  package "memcached"

  template "/etc/memcached.conf" do
    owner "root"
    group "root"
    mode 0644
    source "memcached.conf.erb"
    action :create
  end

  service "memcached" do
    supports :start => true, :stop => true, :restart => true
    action [ :enable, :start ]
  end
end
