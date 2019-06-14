#!/usr/bin/env bash

# modified from Laravel 5 homestead provisioning script @ https://github.com/laravel/settler
# modified from Laravel 5 provisioning script @ https://github.com/mrlami/provisioning-scripts
# Abdulrahman, 2019-6, github:abdumu, twitter:aphpdev

#please: change these variables before using it

#mysql root password, and the extra user and database for your app
MYSQL_ROOT_PASSWORD=""
MYSQL_DATABASE_USER="" #to use it in your app
MYSQL_DATABASE_PASSWORD=''
MYSQL_DATABASE_NAME=""

APP_FOLDER_NAME="test" #your app folder name
SERVER_NAME="localhost" #change it to your domain or ip

#an extra account that has limited ability, www-data group to modifiy apps folder
DEPLOYER_USERNAME=""
DEPLOYER_PASSWORD=""
#used to access deployer account, i.e. from gitlab ci or docker images
DEPLOYER_PUBLIC_AUTHORIZED_KEY=""

#if private make sure to include the token
#github: https://<token>@github.com/owner/repo.git (see https://github.blog/2012-09-21-easier-builds-and-deployments-using-git-over-https-and-oauth/)
#gitlab: https://<token_name>:<token_secret>:@gitlab.com/owner/repo.git (see https://docs.gitlab.com/ee/user/project/deploy_tokens/)
LARAVEL_PROJECT_GIT_REPO=""
LARAVEL_ENV_FILE_TO_PRODUCTION=".env.example" #the name of .env file that we will rename to .env.production

PHP_MEMORY_LIMIT="128M"
PHP_DATE_TIMEZONE="UTC"




#
# dont change after this line, or do if you want.
#


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


# Set Some PHP CLI Settings
# sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.3/cli/php.ini
# sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.3/cli/php.ini
sudo sed -i "s/memory_limit = .*/memory_limit = $PHP_MEMORY_LIMIT/" /etc/php/7.3/cli/php.ini
sudo sed -i "s/;date.timezone.*/date.timezone = $PHP_DATE_TIMEZONE/" /etc/php/7.3/cli/php.ini

# Install Nginx
apt-get install  -y --force-yes nginx

rm /etc/nginx/sites-enabled/default
rm /etc/nginx/sites-available/default
service nginx restart


# sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.3/fpm/php.ini
# sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.3/fpm/php.ini
sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.3/fpm/php.ini
sed -i "s/memory_limit = .*/memory_limit = $PHP_MEMORY_LIMIT/" /etc/php/7.3/fpm/php.ini
sed -i "s/;date.timezone.*/date.timezone = $PHP_DATE_TIMEZONE/" /etc/php/7.3/fpm/php.ini

# Misc Nginx & PHP-FPM Config
sed -i "s/# server_names_hash_bucket_size.*/server_names_hash_bucket_size 64;/" /etc/nginx/nginx.conf
sed -i "s/;listen\.mode.*/listen.mode = 0666/" /etc/php/7.3/fpm/pool.d/www.conf

service nginx restart
service php7.3-fpm restart

# Install Node
apt-get install -y nodejs

# Install SQLite
apt-get install -y sqlite3 libsqlite3-dev

# Install MySQL
debconf-set-selections <<< "mysql-server mysql-server/root_password $MYSQL_ROOT_PASSWORD"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again $MYSQL_ROOT_PASSWORD"
apt-get install -y mysql-server

# Configure MySQL Remote Access
sed -i '/^bind-address/s/bind-address.*=.*/bind-address = 0.0.0.0/' /etc/mysql/my.cnf
mysql --user="root" --password="$MYSQL_ROOT_PASSWORD" -e "GRANT ALL ON *.* TO root@'0.0.0.0' IDENTIFIED BY 'mysql_root_password' WITH GRANT OPTION;"
service mysql restart

mysql --user="root" --password="$MYSQL_ROOT_PASSWORD" -e "CREATE USER '$MYSQL_DATABASE_USER'@'0.0.0.0' IDENTIFIED BY '$MYSQL_DATABASE_PASSWORD';"
mysql --user="root" --password="$MYSQL_ROOT_PASSWORD" -e "GRANT ALL ON *.* TO '$MYSQL_DATABASE_USER'@'0.0.0.0' IDENTIFIED BY '$MYSQL_DATABASE_PASSWORD' WITH GRANT OPTION;"
mysql --user="root" --password="$MYSQL_ROOT_PASSWORD" -e "GRANT ALL ON *.* TO '$MYSQL_DATABASE_USER'@'%' IDENTIFIED BY '$MYSQL_DATABASE_PASSWORD' WITH GRANT OPTION;"
mysql --user="root" --password="$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"
mysql --user="root" --password="$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE $MYSQL_DATABASE_NAME;"
service mysql restart

# Add Timezone Support To MySQL
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql --user=root --password=$MYSQL_ROOT_PASSWORD


# Install A Few Other Things
apt-get install -y redis-server zip unzip acl composer

# Enable Swap Memory
/bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=1024
/sbin/mkswap /var/swap.1
/sbin/swapon /var/swap.1

mkdir /apps
chown -R www-data:www-data /apps
chmod -R 775 /apps

#clone repo
if [! -z "$LARAVEL_PROJECT_GIT_REPO"]
    cd /apps
    git clone "$LARAVEL_PROJECT_GIT_REPO" "$APP_FOLDER_NAME"
    cd "$APP_FOLDER_NAME"
    cp "$LARAVEL_ENV_FILE_TO_PRODUCTION" .env
    sed -i "s/^\(APP_BDOMAIN=\).*/\1$SERVER_NAME/" .env
    sed -i "s/^\(APP_URL=\).*/\1http\:\/\/$SERVER_NAME/" .env
    sed -i "s/^\(SESSION_DOMAIN=\).*/\1\.$SERVER_NAME/" .env
    sed -i "s/^\(DB_DATABASE=\).*/\1$MYSQL_DATABASE_name/" .env
    sed -i "s/^\(DB_USERNAME=\).*/\1$MYSQL_DATABASE_USER/" .env
    sed -i "s/^\(DB_PASSWORD=\).*/\1$MYSQL_DATABASE_PASSWORD/" .env

    composer install
    npm install
    php artisan key:generate
    chmod -R 755 storage
    chmod -R 755 bootstrap/cache

then 
    mkdir /apps/"$APP_FOLDER_NAME"
    mkdir /apps/"$APP_FOLDER_NAME"/public
    echo '<?php echo "hello brother!";' > /apps/"$APP_FOLDER_NAME"/public/index.php
fi

#for ipv6 add this change
# listen [::]:80 default_server ipv6only=on;

echo 'server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /apps/'"$APP_FOLDER_NAME"'/public;
    index index.html index.htm index.php;

    # Make site accessible from http://localhost/
    server_name '"$SERVER_NAME"';

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



sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

sudo service nginx restart

#add new user [deployer for example, and add it to www-data group], to modifiy /apps folder
adduser "$DEPLOYER_USERNAME" --gecos '' --disabled-password -d
echo "$DEPLOYER_USERNAME:$DEPLOYER_PASSWORD" | sudo chpasswd

#add ssh public key to access new user for deployment matter
mkdir -p /home/"$DEPLOYER_USERNAME"/.ssh
chmod 700 /home/"$DEPLOYER_USERNAME"/.ssh
echo "$DEPLOYER_PUBLIC_AUTHORIZED_KEY" >> /home/"$DEPLOYER_USERNAME"/.ssh/authorized_keys
