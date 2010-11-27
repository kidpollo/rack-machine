#
# Cookbook Name:: packages
# Recipe:: default
#

for pacakge_name in node[:packages][:all]
  package pacakge_name
end if node[:packages][:all]

for pacakge_name in node[:packages][node[:instance_role].to_sym]
  package pacakge_name
end if node[:packages][node[:instance_role].to_sym]

