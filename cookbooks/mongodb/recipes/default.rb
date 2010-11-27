# Cookbook Name:: mongodb
# Recipe:: default
if ['db_master', 'solo'].include?(node[:instance_role])

  # ============================================================================
  # INSTALL NEEDED DEPENDANCIES (LUCID, LYNX)
  # TODO: check other dists
  # ============================================================================
  package 'tcsh'
  package 'git-core'
  package 'scons'
  package 'g++'
  package 'libpcre++-dev'
  package 'libboost-dev'
  package 'libreadline-dev'
  package 'xulrunner-1.9.2-dev'
  package 'libboost-program-options-dev'
  package 'libboost-thread-dev'
  package 'libboost-filesystem-dev'
  package 'libboost-date-time-dev'

  # ============================================================================
  # INSTALLATION SETTINGS
  # ============================================================================
  package_tgz       = 'mongodb-src-r1.4.4.tar.gz'
  package_url       = "http://fastdl.mongodb.org/src/#{package_tgz}"
  package_folder    = package_tgz.gsub('.tar.gz', '')
  data_path         = '/db/mongodb/master'
  install_path      = '/usr/local/mongodb'
  log_path          = '/var/log/mongodb'
  pid_path          = '/var/log/mongodb'
  export_path       = "export PATH=$PATH:#{install_path}"

  # Update and check if a new dist includes new binaries
  def executables
    %w{
      mongo mongod mongodump mongoexport mongofiles mongoimport mongorestore
      mongos mongostat
    }
  end

  # ============================================================================
  # NEEDED DIRECTORIES
  # ============================================================================
  directory data_path do
    owner node[:user]
    group node[:user]
    mode 0755
    recursive true
    not_if { File.directory?(data_path) }
  end

  directory log_path do
    owner node[:user]
    group node[:user]
    mode 0755
    recursive true
    not_if { File.directory?(log_path) }
  end

  execute 'install-mongodb' do
    executables = %w{
      mongo mongod mongodump mongoexport mongofiles mongoimport mongorestore
      mongos mongostat
    }

    executables.map! do |file|
      "mv #{file} #{install_path}/"
    end

    command %Q{
      curl -O #{package_url} && tar zxvf #{package_tgz} &&
      mkdir -p #{install_path} &&
      cd #{package_folder} &&
      scons all &&
      scons --prefix=/opt/mongo install &&
      #{executables.join(' && ')} &&
      cd .. &&
      rm #{package_tgz} &&
      rm -rf #{package_folder}
    }
    not_if { File.directory?(install_path) }
  end

  execute 'add-to-path' do
    command %Q{
      echo '#{export_path}' >> /etc/profile
    }
    not_if "grep '#{export_path}' /etc/profile"
  end

  template '/etc/init.d/mongodb' do
    source 'mongodb.erb'
    owner 'root'
    group 'root'
    mode 0755
    variables({
      :data_path => data_path,
      :install_path => install_path,
      :log_path => log_path
    })
  end

  execute 'add-mongodb-to-default-run-level' do
    command %Q{
      update-rc.d mongodb defaults
    }
  end

  execute 'ensure-mongodb-is-running' do
    command %Q{
      /etc/init.d/mongodb start
    }
    not_if 'pgrep mongod'
  end

  template '/usr/local/bin/mongodb_backup' do
    source 'mongodb_backup.erb'
    owner 'root'
    group 'root'
    mode 0755
  end

  cron 'mongodb_backup' do
    cron_hour =  if node[:backup_interval].to_s == '24'
      '1'    # 0100 Pacific, per support's request
      # NB: Instances run in the Pacific (Los Angeles) timezone
    elsif node[:backup_interval]
      "*/#{node[:backup_interval]}"
    end

    minute   '10'
    hour     cron_hour
    day      '*'
    month    '*'
    weekday  '*'
    command  '/usr/local/bin/mongodb_backup /data/mongodbbackups'
    not_if { node[:backup_window].to_s == '0' }
  end

end
