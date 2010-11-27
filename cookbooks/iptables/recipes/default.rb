#
# Cookbook Name:: iptables
# Recipe:: default
#

case node[:platform]
when "centos", "redhat", "fedora"
  package "iptables" do
    action :install
  end
end

template node[:iptables_config] do
  owner 'root'
  group 'root'
  mode 0644
  source "iptables.erb"
end

case node[:platform]
when "centos", "redhat", "fedora"
  service "iptables" do
    action [ :enable, :start ]
  end
when "ubuntu", "debian"
  execute "iptables-apply" do
    command "iptables-restore < /etc/network/iptables"
  end
end

