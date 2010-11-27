#
# Cookbook Name:: mysql
# Recipe:: default
#
# Copyright 2008, OpsCode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#include this recipe to disable the awful apparmor!
include_recipe "apparmor"

#client and devel libraries on all roles
package "mysql-devel" do
  package_name value_for_platform(
    [ "centos", "redhat", "suse" ] => { "default" => "mysql-devel" },
    "default" => 'libmysqlclient-dev'
  )
  action :install
end

package "mysql-client" do
  package_name value_for_platform(
    [ "centos", "redhat", "suse" ] => { "default" => "mysql" },
    "default" => "mysql-client"
  )
  action :install
end

if ['db_master', 'solo'].include?(node[:instance_role])
  package "mysql-server" do
    action :install
  end
  
  mysql_server_path = case node[:platform]
  when "ubuntu","debian"
    "/var/lib/mysql"
  else
    "/var/mysql"
  end
  
  # TODO: see why changing data dir in lucid lynx does not work
  service "mysql" do
    action :stop
  end
  
  template "/etc/mysql/my.cnf" do
    owner 'root'
    group 'root'
    mode 0644
    source "my.conf.erb"
    variables(:bind_only_to_localhost => (node[:instance_role] == 'solo' ? true : false), :mysql_path => node[:mysql_path], :mysql_options => node[:mysql_options] )
  end
  
  execute "install-mysql" do
    command "mkdir -p #{node[:mysql_path]}; mkdir -p #{node[:mysql_path]}/log; cp -R #{mysql_server_path}/** #{node[:mysql_path]}/; rm #{node[:mysql_path]}/ib*; chown -R mysql:mysql #{node[:mysql_path]}"
    not_if do FileTest.directory?(node[:mysql_path]) end
  end
  
  directory node[:mysql_path] do
    owner "mysql"
    group "mysql"
    mode 0755
    recursive true
  end
  
  directory "#{node[:mysql_path]}/mysql" do
    owner "mysql"
    group "mysql"
    mode 0755
    recursive true
  end
  
  directory "#{node[:mysql_path]}/log" do
    owner "mysql"
    group "mysql"
    mode 0755
    recursive true
  end
  
  service "mysql" do
    action [:enable, :start]
    start_command '/etc/init.d/mysql start'
  end

  # TODO: don't pass mysql password to a tty, instead upload and setup
  # a ".my.cnf" file. or dynamically delete history.
  execute "mysql-root-pass" do
    command "/usr/bin/mysqladmin -u root password '#{node[:db_pass]}'; true"
  end if node[:db_pass]

  # Grant permissions to app hosts
  template "/tmp/mysql_acces.sql" do
    owner 'root'
    group 'root'
    mode 0644
    source "mysql_acces.sql.erb"
  end

  execute "grant-acces-permissions-to-app-hosts" do
    command "mysql -u root -p'#{node[:db_pass]}' < /tmp/mysql_acces.sql"
  end

  template "/usr/local/bin/mysql_backup" do
    source "mysql_backup.erb"
    owner "root"
    group "root"
    mode 0755
    variables(:root_pwd => node[:db_pass])
  end

  cron "mysql_backup" do
    cron_hour =  if node[:backup_interval].to_s == '24'
      "1"    # 0100 Pacific, per support's request
      # NB: Instances run in the Pacific (Los Angeles) timezone
    elsif node[:backup_interval]
      "*/#{node[:backup_interval]}"
    end

    minute   '20'
    hour     cron_hour
    day      '*'
    month    '*'
    weekday  '*'
    command  "/usr/local/bin/mysql_backup /data/mysql_backups"
    not_if { node[:backup_window].to_s == '0' }
  end

end
