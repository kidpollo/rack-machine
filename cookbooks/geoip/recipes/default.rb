if ['app_master', 'solo'].include?(node[:instance_role])
  
  package_tgz    = 'GeoIP-1.4.6.tar.gz'
  package_folder = package_tgz.gsub('.tar.gz', '')
  package_url    = 'http://geolite.maxmind.com/download/geoip/api/c/'
  prefix         = '/user/local/bin'

  execute 'install-geoip' do
    command %Q{
      curl -O #{package_url}#{package_tgz} &&
      tar zxvf #{package_tgz} &&
      cd #{package_folder} &&
      ./configure --prefix=#{prefix} &&
      make install
    }
  end

end
