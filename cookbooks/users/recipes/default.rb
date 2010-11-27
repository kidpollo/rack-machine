#
# Cookbook Name:: users
# Recipe:: default
#

node[:users].each do |user|
  group user[:username] do
    gid user[:gid]
  end

  user user[:username] do
    password user[:password].crypt(user[:username]) if user[:password]
    uid user[:uid]
    gid user[:gid]
    shell user[:shell] || "/bin/bash"
    action :create
  end

  directory "/data/home/#{user[:username]}" do
    owner user[:uid]
    group user[:gid]
    mode 0755
    recursive true
  end

  link "/home/#{user[:username]}" do
    to "/data/home/#{user[:username]}"
  end

  execute "chown homedir to user" do
    command "chown -R #{user[:username]}:#{user[:username]} /data/home/#{user[:username]}"
  end

  directory "/data/home/#{user[:username]}/.ssh" do
    owner user[:uid]
    group user[:gid]
    mode 0700
  end

  for custom_file in user[:custom_files] || []
    template (custom_file[:path] || "/data/home/#{user[:username]}/#{custom_file[:name]}") do
      owner user[:uid]
      group user[:gid]
      mode custom_file[:mode] || 0744
      variables :content => custom_file[:content]
      source "custom.erb"
    end
  end

  template "/data/home/#{user[:username]}/.ssh/authorized_keys" do
    owner user[:uid]
    group user[:gid]
    mode 0600
    source "authorized_keys.erb"

    variables :user => user
  end if user[:authorized_keys]

  template "/data/home/#{user[:username]}/.ssh/known_hosts" do
    owner user[:uid]
    group user[:gid]
    mode 0600
    source "known_hosts.erb"

    variables :user => user
  end if user[:known_hosts]

  if user[:keys]
    template "/data/home/#{user[:username]}/.ssh/id_rsa" do
      owner user[:uid]
      group user[:gid]
      mode 0600
      source "custom.erb"
      variables :content => user[:keys][:private]
    end if user[:keys][:private]

    template "/data/home/#{user[:username]}/.ssh/id_rsa.pub" do
      owner user[:uid]
      group user[:gid]
      mode 0600
      source "custom.erb"
      variables :content => user[:keys][:public]
    end if user[:keys][:public]
  end
end
