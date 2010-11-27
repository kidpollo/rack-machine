#
# Cookbook Name:: rack_apps
# Recipe:: default
#

if ['app_master', 'solo', 'app_slave'].include?(node[:instance_role])
  include_recipe "nginx"
  include_recipe 'monit'

  node[:applications].each do |app|
    app[:user] ||= node[:user]
    app[:group] ||= app[:user]
    app_dir = "/data/#{app[:name]}"
    app_restart_command = ""
    instance_symlinks = {}

    directory app_dir do
      owner app[:user]
      group app[:group]
      mode 0755
      action :create
      recursive true
    end

    directory "#{app_dir}/shared" do
      owner app[:user]
      group app[:group]
      mode 0755
      action :create
      recursive true
    end

    directory "#{app_dir}/shared/log" do
      owner app[:user]
      group app[:group]
      mode 0755
      action :create
      recursive true
    end

    directory "#{app_dir}/shared/config/" do
      owner app[:user]
      group app[:group]
      mode 0755
      action :create
    end

    # Nginx Setup
    # -----------
    template "#{node[:nginx_dir]}/apps/#{app[:name]}.conf" do
      owner app[:user]
      group app[:group]
      mode 0644
      source "app.conf.erb"
      vars = {
        :app_name => app[:name],
        :app_dir => app_dir,
        :http_bind_port => app[:bind_port] || 80,
        :server_names => app[:server_names],
        :custom_conf => app[:custom_nginx_conf],
        :server_type => app[:app_server][:type]
      }

      if app[:app_server][:type] == 'thin'
        vars.merge!(:ports => [*app[:app_server][:ports]])
      end

      variables(vars)
    end

    #ssl conf
    if app[:ssl]
      app[:ssl].each do |ssl|

        unique_ssl_id = "#{app[:name]}_#{ssl[:ip].gsub('.','_')}_ssl"
        key_path = "#{node[:nginx_dir]}/apps/ssl/#{unique_ssl_id}.key"
        crt_path = "#{node[:nginx_dir]}/apps/ssl/#{unique_ssl_id}.crt"

        directory "#{node[:nginx_dir]}/apps/ssl" do
          owner app[:user]
          group app[:group]
          mode 0600
          action :create
          recursive true
        end

        execute "output-ssl-certs" do
          command %Q{
            echo '#{ssl[:key]}' > #{key_path}
            echo '#{ssl[:crt]}' > #{crt_path}
            echo '#{ssl[:chain]}' >> #{crt_path}
          }
        end

        template "#{node[:nginx_dir]}/apps/#{unique_ssl_id}.conf" do
          owner app[:user]
          group app[:group]
          mode 0644
          source "app_ssl.conf.erb"
          vars = {
            :unique_ssl_id => unique_ssl_id,
            :app_name => app[:name],
            :app_dir => app_dir,
            :http_bind_port => "#{ssl[:ip]}:443",
            :server_names => ssl[:server_names],
            :custom_conf => app[:custom_nginx_conf],
            :server_type => app[:app_server][:type],
            :key_path => key_path,
            :crt_path => crt_path,
            :fqdn     => ssl[:fqdn],
            :ip       => ssl[:ip]
          }

          if app[:app_server][:type] == 'thin'
            vars.merge!(:ports => [*app[:app_server][:ports]])
          end

          variables(vars)
        end
      end
    end

    # Tell logrotate to handle production logs.
    #
    template "/etc/logrotate.d/#{app[:name]}_app_logs" do
      owner app[:user]
      group app[:group]
      mode 0777
      source 'log.logrotate.erb'
      action :create
      variables(
        :logs_dir => "#{app_dir}/shared/log/*.log",
        :app_name => app[:name]
      )
      backup false
    end

    # Memcached setup
    # ---------------
    if app[:memcached] && app[:memcached] == true
      include_recipe "memcached"
      #add to symlinks
      instance_symlinks.merge!({"config/memcached.yml" => "config/memcached.yml"})

      template "#{app_dir}/shared/config/memcached.yml" do
        owner app[:user]
        group app[:group]
        mode 0644
        source "memcached.yml.erb"
        action :create

        variables(:app => app)
      end
    end

    # Mysql setup
    # -----------
    if app[:mysql] && app[:mysql] == true

      #add to symlinks
      instance_symlinks.merge!({"config/database.yml" => "config/database.yml"})
      adapter = if app[:activerecord_adapter]
        app[:activerecord_adapter]
      else
        'mysql'
      end
      
      db_host = (node[:instance_role] == 'solo' ? 'localhost' : node[:db_host])
      db_user_attrs = {:user => app[:user], :password => app[:password], :database => "#{app[:name]}_production", :db_host => db_host, :adapter => adapter }
      
      template "#{app_dir}/shared/config/database.yml" do
        owner app[:user]
        group app[:group]
        mode 0655
        source "database.yml.erb"
        variables(db_user_attrs)
        action :create
      end

      # Create empty db
      template "/tmp/empty-#{app[:name]}-db.sql" do
        owner 'root'
        group 'root'
        mode 0644
        source "empty-db.sql.erb"
        variables(db_user_attrs)
      end

      # TODO: don't pass mysql password to a tty, instead upload and setup
      # a ".my.cnf" file. or dynamically delete history.
      #
      # TODO: Use migrations take care of db initialization.
      #
      # TODO: It might be needed to apend 'app_slave' to this config.
      # And in fact, app_master should be here too!
      # if in the future we want to add app/mysql-slave servers on the same instance.
      #
      execute "create-empty-db-for-#{app[:name]}" do
        command "mysql -u root -p'#{node[:db_pass]}' -h #{db_host} < /tmp/empty-#{app[:name]}-db.sql"
      end
    end

    # Mongodb setup
    # -------
    if app[:mongodb] && app[:mongodb] == true
      #add to symlinks
      instance_symlinks.merge!({"config/mongodb.yml" => "config/mongodb.yml"})

      template "/data/#{app[:name]}/shared/config/mongodb.yml" do
        source "mongodb.yml.erb"
        owner app[:user]
        group app[:group]
        mode 0744
        variables({
          :app_name => app[:name]
        })
      end
    end

    # Setup app server config
    if app[:app_server][:type] == 'unicorn'
      # TODO check if deploy shpuld be generating the tmp/pids or not?
      directory "#{app_dir}/shared/tmp/pids" do
        owner app[:user]
        group app[:group]
        mode 0755
        action :create
        recursive true
      end

      #add to symlinks
      instance_symlinks.merge!({"config/unicorn.rb" => "config/unicorn.rb"})
      # unicorn.rb
      template "#{app_dir}/shared/config/unicorn.rb" do
        owner app[:user]
        group app[:group]
        mode 0644
        source "unicorn.rb.erb"
        variables(
          :app_name => app[:name],
          :app_dir => app_dir,
          :workers => app[:app_server][:workers] ? app[:app_server][:workers] : 6
        )
      end
      
      # Set app restart command.
      app_restart_command = "/etc/init.d/unicorn_#{app[:name]} upgrade"
      
      #execute 'upgrade unicorn' do
      #  command "/etc/init.d/unicorn_#{app[:name]} upgrade"
      #end

      # init.d/unicorn
      template "/etc/init.d/unicorn_#{app[:name]}" do
        owner app[:user]
        group app[:group]
        mode 0755
        source "unicorn.erb"
        variables(
          :app_name => app[:name],
          :app_dir => app_dir,
          :rails_app => app[:rails_app]
        )
      end
    elsif app[:app_server][:type] == 'thin'
      # Setup a thin config file
      execute "create-thin-config-for-#{app[:name]}" do
        command "thin config --config #{app_dir}/shared/config/thin.yml \
                             --chdir /data/apps/#{app[:name]}/current \
                             --environment production \
                             --log #{app_dir}/shared/log/thin.log \
                             --pid #{app_dir}/shared/pids/thin.pid \
                             --user #{app[:user]} \
                             --group #{app[:group]} \
                             --port #{[*app[:ports]].first} \
                             --servers #{[*app[:ports]].size}".squeeze(" ")
      end

      app_restart_command  = "thin restart --config #{app_dir}/shared/config/thin.yml"
      execute "startup-#{app[:name]}" do
        command "thin start --config #{app_dir}/shared/config/thin.yml"
        only_if "[[ -f #{app_dir}/shared/config/thin.yml ]]"
      end
    end
        
    if app[:config_files]
      app[:config_files].each do |config_file|
        #add to symlinks
        instance_symlinks.merge!({config_file[:path] => config_file[:path]})
        
        directory File.dirname("/data/#{app[:name]}/shared/#{config_file[:path]}") do
          owner app[:user]
          group app[:group]
          mode 0755
          action :create
          recursive true
        end
        
        file "/data/#{app[:name]}/shared/#{config_file[:path]}" do
          content config_file[:content]
          owner app[:user]
          group app[:group]
          mode 0744
          action :create
        end
      end
    end

    deploy app_dir do
      repo app[:repo]
      environment "RAILS_ENV" => node[:environment][:framework_env], "RACK_ENV" => node[:environment][:framework_env]
      revision app[:revision]
      action app[:action]
      migration_command "HOME=/home/#{app[:user]} && #{app[:migration_command]}"
      migrate app[:migrate]
      restart_command app[:restart_command] ? app[:restart_command] : app_restart_command
      #restart_command "HOME=/home/#{app[:user]} #{app[:restart_command] ? app[:restart_command] : app_restart_command}"
      create_dirs_before_symlink app[:create_dirs_before_symlink]
      user app[:user]
      group app[:group]
      symlink_before_migrate app[:symlink_before_migrate].merge(instance_symlinks)
      symlinks app[:symlinks]
      purge_before_symlink app[:purge_before_symlink]

      before_migrate do
        if app[:bundler] && app[:bundler] == true
          execute "bundle install" do
            user app[:user]
            command "cd #{release_path} && HOME=/home/#{app[:user]} bundle install"
          end
        end
      end

    end

  end if node[:applications]

  service "nginx" do
    action [ :restart ]
  end
end
