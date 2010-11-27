#
# Cookbook Name:: cron
# Recipe:: default
#

for cronjob in node[:cronjobs]
  cron cronjob[:name] do
    minute  cronjob[:minute]
    hour    cronjob[:hour]
    day     cronjob[:day]
    month   cronjob[:month]
    weekday cronjob[:weekday]
    user    cronjob[:user]
    command cronjob[:command]
  end if cronjob[:instance_role] == node[:instance_role]
end if node[:cronjobs]
