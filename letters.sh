#!/usr/bin/env bash

PHP_MEMORY_LIMIT=128M
APPS_DIR=/apps

setup_apps_directory
provision_software
serve sailsletter sailsletter.loc
serve letters letters.newztime.loc sendy


function setup_apps_directory() {
    mkdir -p $APPS_DIR
    sudo chown www-data:www-data $APPS_DIR
    sudo chmod -R 775 $APPS_DIR
}

function provision_software(){
    # Update Package List
    apt-get update

    # Update System Packages
    apt-get -y upgrade

    # Force Locale
    echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale
    locale-gen en_US.UTF-8

    # Install Some PPAs
    apt-get install -y software-properties-common curl

    apt-add-repository -y ppa:nginx/stable
    apt-add-repository -y ppa:ondrej/php5-5.6

    curl -s https://packagecloud.io/gpg.key | sudo apt-key add -
    echo "deb http://packages.blackfire.io/debian any main" | sudo tee /etc/apt/sources.list.d/blackfire.list

    curl --silent --location https://deb.nodesource.com/setup_0.12 | sudo bash -

    # Update Package Lists
    apt-get update

    # Install Some Basic Packages
    apt-get install -y build-essential dos2unix gcc git libmcrypt4 libpcre3-dev \
    make python2.7-dev python-pip re2c supervisor unattended-upgrades whois vim

    # Set My Timezone
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime

    # Install PHP Stuffs
    apt-get install -y php5-cli php5-dev php-pear \
    php5-mysqlnd php5-pgsql php5-sqlite \
    php5-apcu php5-json php5-curl php5-gd \
    php5-gmp php5-imap php5-mcrypt php5-xdebug \
    php5-memcached

    # Make MCrypt Available
    ln -s /etc/php5/conf.d/mcrypt.ini /etc/php5/mods-available
    sudo php5enmod mcrypt

    # Install Mailparse PECL Extension
    pecl install mailparse
    echo "extension=mailparse.so" > /etc/php5/mods-available/mailparse.ini
    ln -s /etc/php5/mods-available/mailparse.ini /etc/php5/cli/conf.d/20-mailparse.ini

    # Install Composer
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer

    ## TODO:
    #1. create deployer user
    #2. create mrlami user
    #3. add composer to (deployer and mrlami) their global paths
        #printf "\nPATH=\"/home/vagrant/.composer/vendor/bin:\$PATH\"\n" | tee -a /home/vagrant/.profile
    #4. install laravel envoy
        #sudo su vagrant <<'EOF'
        #/usr/local/bin/composer global require "laravel/envoy=~1.0"
        #EOF

    # Set Some PHP CLI Settings
    sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php5/cli/php.ini
    sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php5/cli/php.ini
    sudo sed -i "s/memory_limit = .*/memory_limit = $PHP_MEMORY_LIMIT/" /etc/php5/cli/php.ini
    sudo sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php5/cli/php.ini

    # Install Nginx & PHP-FPM
    apt-get install -y nginx php5-fpm

    rm /etc/nginx/sites-enabled/default
    rm /etc/nginx/sites-available/default
    service nginx restart

    # Setup Some PHP-FPM Options
    ln -s /etc/php5/mods-available/mailparse.ini /etc/php5/fpm/conf.d/20-mailparse.ini

    sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php5/fpm/php.ini
    sed -i "s/display_errors = .*/display_errors = On/" /etc/php5/fpm/php.ini
    sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php5/fpm/php.ini
    sed -i "s/memory_limit = .*/memory_limit = $PHP_MEMORY_LIMIT/" /etc/php5/fpm/php.ini
    sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" /etc/php5/fpm/php.ini
    sed -i "s/post_max_size = .*/post_max_size = 100M/" /etc/php5/fpm/php.ini
    sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php5/fpm/php.ini

    echo "xdebug.remote_enable = 1" >> /etc/php5/fpm/conf.d/20-xdebug.ini
    echo "xdebug.remote_connect_back = 1" >> /etc/php5/fpm/conf.d/20-xdebug.ini
    echo "xdebug.remote_port = 9000" >> /etc/php5/fpm/conf.d/20-xdebug.ini
    echo "xdebug.max_nesting_level = 250" >> /etc/php5/fpm/conf.d/20-xdebug.ini

    # Copy fastcgi_params to Nginx because they broke it on the PPA
    cat > /etc/nginx/fastcgi_params << EOF
    fastcgi_param   QUERY_STRING        \$query_string;
    fastcgi_param   REQUEST_METHOD      \$request_method;
    fastcgi_param   CONTENT_TYPE        \$content_type;
    fastcgi_param   CONTENT_LENGTH      \$content_length;
    fastcgi_param   SCRIPT_FILENAME     \$request_filename;
    fastcgi_param   SCRIPT_NAME     \$fastcgi_script_name;
    fastcgi_param   REQUEST_URI     \$request_uri;
    fastcgi_param   DOCUMENT_URI        \$document_uri;
    fastcgi_param   DOCUMENT_ROOT       \$document_root;
    fastcgi_param   SERVER_PROTOCOL     \$server_protocol;
    fastcgi_param   GATEWAY_INTERFACE   CGI/1.1;
    fastcgi_param   SERVER_SOFTWARE     nginx/\$nginx_version;
    fastcgi_param   REMOTE_ADDR     \$remote_addr;
    fastcgi_param   REMOTE_PORT     \$remote_port;
    fastcgi_param   SERVER_ADDR     \$server_addr;
    fastcgi_param   SERVER_PORT     \$server_port;
    fastcgi_param   SERVER_NAME     \$server_name;
    fastcgi_param   HTTPS           \$https if_not_empty;
    fastcgi_param   REDIRECT_STATUS     200;
    EOF

    service nginx restart
    service php5-fpm restart

    ## TODO:
    #1. add deployer and mrlami To www-data group
        #usermod -a -G www-data vagrant
        #id vagrant
        #groups vagrant

    # Install Node
    apt-get install -y nodejs
    /usr/bin/npm install -g grunt-cli
    /usr/bin/npm install -g gulp
    /usr/bin/npm install -g bower

    # Install SQLite
    apt-get install -y sqlite3 libsqlite3-dev

    # Install MySQL
    debconf-set-selections <<< "mysql-server mysql-server/root_password password secret"
    debconf-set-selections <<< "mysql-server mysql-server/root_password_again password secret"
    apt-get install -y mysql-server-5.6

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

    # Enable Swap Memory
    /bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=1024
    /sbin/mkswap /var/swap.1
    /sbin/swapon /var/swap.1
}

function serve() {
    # parameter $1 - directory
    # parameter $2 - url
    # parameter $3 - check if sending up sendy

    APP_DIR=$APPS_DIR/$1
    sudo mkdir -p $APP_DIR/public $APP_DIR/logs

    VHOST_SERVE="
        server {
            listen 80;
            server_name $2;

            root $APP_DIR/public;
            index index.html index.php;

            #access_log off;
            access_log  $APP_DIR/logs/access.log;
            error_log  $APP_DIR/logs/error.log error;

            location / {
                try_files \$uri \$uri/ =404;
            }

            location ~ \.php$ {
                include snippets/fastcgi-php.conf;
                fastcgi_pass unix:/var/run/php5-fpm.sock;
            }
        }
    "

    VHOST_SENDY="
        server {
            listen 80;
            server_name $2;

            root $APP_DIR/public;

            autoindex off;
            index index.html index.htm index.php;
            charset utf-8;

            #access_log off;
            access_log  $APP_DIR/logs/access.log;
            error_log  $APP_DIR/logs/error.log error;

            location / {
                try_files \$uri \$uri/ \$uri.php?\$args;
            }

            location /l/ {
                rewrite ^/l/([a-zA-Z0-9/]+)$ /l.php?i=\$1 last;
            }

            location /t/ {
                rewrite ^/t/([a-zA-Z0-9/]+)$ /t.php?i=\$1 last;
            }

            location /w/ {
                rewrite ^/w/([a-zA-Z0-9/]+)$ /w.php?i=\$1 last;
            }

            location /unsubscribe/ {
                rewrite ^/unsubscribe/(.*)$ /unsubscribe.php?i=\$1 last;
            }

            location /subscribe/ {
                rewrite ^/subscribe/(.*)$ /subscribe.php?i=\$1 last;
            }

            location = /favicon.ico { access_log off; log_not_found off; }
            location = /robots.txt  { access_log off; log_not_found off; }

            error_page 404 /index.php;

            location ~ \.php$ {
                try_files \$uri =404;
                fastcgi_split_path_info ^(.+\.php)(/.+)$;
                fastcgi_pass unix:/var/run/php5-fpm.sock;
                fastcgi_index index.php;
                include fastcgi_params;
            }

            location ~ /\.ht {
                deny all;
            }
        }
    "

    if [ -z "$3" ]; then
        VHOST=$VHOST_SERVE
    elif [ "$3" = "sendy" ]; then
        VHOST=$VHOST_SENDY
    fi

    sudo bash -c "echo '$VHOST' > /etc/nginx/sites-available/$1.conf"
    sudo ln -sf "/etc/nginx/sites-available/$1.conf" "/etc/nginx/sites-enabled/$1.conf"
    sudo service nginx restart
}