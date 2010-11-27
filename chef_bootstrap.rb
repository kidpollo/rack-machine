#!/usr/bin/env ruby

def cmd cmd
  puts "[4;36;1m#{cmd}[0m"; system(cmd)
  puts
end

def title text
  puts
  puts '**' + " [4;35;1m#{text}[0m"
  puts '*' * 80
end

title 'Chef bootstrapping is starting now!'

# TODO: setup versions for packages
title 'Installing basic apt packages'
  cmd 'aptitude -y update'
  cmd 'aptitude -y install ssh build-essential htop curl rsync libreadline5'

# Aptitude or downloaded debian package?
title 'Installing ruby!'
  cmd 'wget http://rubyforge.org/frs/download.php/68720/ruby-enterprise_1.8.7-2010.01_amd64.deb'
  cmd 'dpkg -i ruby-enterprise_1.8.7-2010.01_amd64.deb'

title 'Installing rubygems!'
  cmd "wget 'http://rubyforge.org/frs/download.php/69365/rubygems-1.3.6.tgz'"
  cmd 'tar xf rubygems-1.3.6.tgz'
  cmd 'cd rubygems* && ruby setup.rb --no-ri --no-rdoc'
  cmd 'ln -sfv /usr/bin/gem1.8 /usr/bin/gem'

title 'Setting up gemsources.'
  cmd 'gem sources -a http://gemcutter.org'

title 'Installing some gems'
  cmd 'gem install bundler --no-ri --no-rdoc'
  cmd 'gem install json --version=1.4.2  --no-ri --no-rdoc'
  cmd 'gem install chef --version=0.8.16 --no-ri --no-rdoc'
  cmd 'gem install ohai --version=0.5.6  --no-ri --no-rdoc --source http://gems.opscode.com --source http://gems.rubyforge.org'

title 'Uninstalling some gems'
  some_gems = %q{rails rack actionmailer actionpack activerecord activeresource activesupport}
  some_gems.each { |gem| cmd "gem uninstall -a -I #{gem}" }
  cmd 'gem uninstall json --version=1.4.6 -q'
  cmd 'gem uninstall ohai --version=0.5.8 -q'

title 'It seems to have worked!'
