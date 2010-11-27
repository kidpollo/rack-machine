def install_gem(gem)
  gem = {:name => gem} if gem.kind_of? String

  gem_package gem[:name] do
    if gem[:version] && !gem[:version].empty?
      version gem[:version]
    end
    if gem[:source]
      source gem[:source]
    end
    action :install
  end
end

node[:gems][:all].each do |gem|
  install_gem(gem)
end if node[:gems][:all]

node[:gems][node[:instance_role].to_sym].each do |gem|
  install_gem(gem)
end if node[:gems][node[:instance_role].to_sym]
