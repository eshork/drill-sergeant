#!/bin/bash

/usr/bin/apt-get -y update
/usr/bin/apt-get -y install build-essential
/usr/bin/apt-get -y install nodejs
/usr/bin/apt-get -y install git
/usr/bin/apt-get -y install libcurl4-openssl-dev


/usr/bin/which rvm || /usr/bin/curl -sSL https://get.rvm.io | /bin/bash -s stable
/usr/sbin/usermod -a -G rvm vagrant
source /etc/profile.d/rvm.sh
/usr/local/rvm/bin/rvm --default install 2.1.2


gem install sinatra
gem install sinatra-contrib
gem install padrino



# package { 'nodejs': }

# package { 'git': }

# package { 'build-essential': }

# ->
# exec { '/usr/bin/which rvm || /usr/bin/curl -sSL https://get.rvm.io | /bin/bash -s stable': }
# ->
# exec { '/usr/local/rvm/bin/rvm install ruby-2.1.2 || echo already have ruby-2.1.2': }
