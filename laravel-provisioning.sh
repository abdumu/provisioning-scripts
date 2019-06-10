#!/usr/bin/env bash

# modified from Laravel 5 homestead provisioning script @ https://github.com/laravel/settler
# modified from Laravel 5 provisioning script @ https://github.com/mrlami/provisioning-scripts

#please: change secret to anything else for mysql

# Update Package List
apt-get update
apt-get upgrade -y

# Force Locale
echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale
locale-gen en_US.UTF-8

# Install Some PPAs
apt-get install -y software-properties-common curl wget

apt-add-repository ppa:nginx/stable -y
apt-add-repository ppa:chris-lea/redis-server -y
apt-add-repository ppa:ondrej/php -y

curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -

# Update Package Lists
apt-get update

# Install Some Basic Packages
apt-get install -y build-essential gcc git libmcrypt4 libpcre3-dev \
make re2c supervisor unattended-upgrades whois vim 


# Set My Timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Install PHP Stuffs
apt-get install -y php7.3-fpm php7.3-cli php7.3-mysql \
php7.3-gd php7.3-imagick php7.3-recode php7.3-tidy php7.3-xmlrpc \
php7.3-common php7.3-curl php7.3-mbstring php7.3-xml php7.3-bcmath \
php7.3-bz2 php7.3-intl php7.3-json php7.3-readline php7.3-zip

# php7.0-mcrypt is available, but is already compiled in via ppa:ondrej/php

# Install Composer
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

# Set Some PHP CLI Settings
# sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.3/cli/php.ini
# sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.3/cli/php.ini
sudo sed -i "s/memory_limit = .*/memory_limit = 128M/" /etc/php/7.3/cli/php.ini
sudo sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.3/cli/php.ini

# Install Nginx
apt-get install  -y --force-yes nginx

rm /etc/nginx/sites-enabled/default
rm /etc/nginx/sites-available/default
service nginx restart


# sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.3/fpm/php.ini
# sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.3/fpm/php.ini
sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.3/fpm/php.ini
sed -i "s/memory_limit = .*/memory_limit = 128M/" /etc/php/7.3/fpm/php.ini
sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.3/fpm/php.ini

# Misc Nginx & PHP-FPM Config
sed -i "s/# server_names_hash_bucket_size.*/server_names_hash_bucket_size 64;/" /etc/nginx/nginx.conf
sed -i "s/;listen\.mode.*/listen.mode = 0666/" /etc/php/7.3/fpm/pool.d/www.conf

service nginx restart
service php5-fpm restart

# Install Node
apt-get install -y nodejs

# Install SQLite
apt-get install -y sqlite3 libsqlite3-dev

# Install MySQL
debconf-set-selections <<< "mysql-server mysql-server/root_password secret"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again secret"
apt-get install -y mysql-server

# Configure MySQL Remote Access
sed -i '/^bind-address/s/bind-address.*=.*/bind-address = 0.0.0.0/' /etc/mysql/my.cnf
mysql --user="root" --password="secret" -e "GRANT ALL ON *.* TO root@'0.0.0.0' IDENTIFIED BY 'secret' WITH GRANT OPTION;"
service mysql restart

mysql --user="root" --password="secret" -e "CREATE USER 'homestead'@'0.0.0.0' IDENTIFIED BY 'secret';"
mysql --user="root" --password="secret" -e "GRANT ALL ON *.* TO 'homestead'@'0.0.0.0' IDENTIFIED BY 'secret' WITH GRANT OPTION;"
mysql --user="root" --password="secret" -e "GRANT ALL ON *.* TO 'homestead'@'%' IDENTIFIED BY 'secret' WITH GRANT OPTION;"
mysql --user="root" --password="secret" -e "FLUSH PRIVILEGES;"
mysql --user="root" --password="secret" -e "CREATE DATABASE homestead;"
service mysql restart

# Add Timezone Support To MySQL
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql --user=root --password=secret mysql


# Install A Few Other Things
apt-get install -y redis-server

# Enable Swap Memory
/bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=1024
/sbin/mkswap /var/swap.1
/sbin/swapon /var/swap.1

echo "export $HOME/.composer/vendor/bin:$PATH" >> ~/.bash_profile

mkdir /apps
mkdir /apps/test
mkdir /apps/test/public
echo '<?php echo "hello brother!";' > /apps/test/public/index.php

#for ipv6 add this change
# listen [::]:80 default_server ipv6only=on;

echo 'server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /apps/test/public;
    index index.html index.htm index.php;

    # Make site accessible from http://localhost/
    server_name localhost;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";

    charset utf-8;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php7.3-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}' > /etc/nginx/sites-available/default


chown -R www-data:www-data /apps
chmod -R 775 /apps

sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

sudo service nginx restart

