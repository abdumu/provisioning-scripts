# provisioning-scripts
Web Application Startup script for ubuntu with Laravel support


#TODO
- edit /etc/supervisor/supervisord.conf (add `chown=deployer:www-data` under `[unix_http_server]`)
- create laravel-worker.conf for supervisor
