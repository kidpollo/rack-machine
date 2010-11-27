
def install_4qm
  include_recipe 'mysql'

  execute 'setup-q4m' do
    command 'wget http://q4m.kazuhooku.com/dist/old/mysql-5.1.41-linux-x86_64-glibc23-with-fast-mutexes-q4m-0.8.9.tar.gz'
    command 'unzip *.gz'
    command 'tar -xvf mysql-5.1.41-linux-x86_64-glibc23-with-fast-mutexes-q4m-0.8.9.tar'
    command 'cd q4m-0.8.9-linux-x86_64'
    command 'sudo cp libqueue_engine.so /usr/lib/mysql/plugin'
    command 'sudo chmod 777 /usr/lib/mysql/plugin/libqueue_engine.so'
    command 'mysql -u root -p -f mysql < support-files/install.sql'
  end

end

install_4qm if ['db_master', 'solo'].include?(node[:instance_role])

