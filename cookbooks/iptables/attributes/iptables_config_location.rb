case platform
when "redhat","centos","fedora","suse"
  iptables_config "/etc/sysconfig/iptables"
when "debian","ubuntu"
  iptables_config "/etc/network/iptables"
end
