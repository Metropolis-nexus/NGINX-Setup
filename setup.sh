#!/bin/sh

# Copyright (C) 2024-2025 Thien Tran, GrapheneOS
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

set -eu

output(){
    printf '\e[1;34m%-6s\e[m\n' "${@}"
}

unpriv(){
    sudo -u nobody "$@"
}

deployment_mode_prompt(){
    output 'Regular deployment or Stream deployment?'
    output 
    output '1) Regular'
    output '2) Stream'
    output 'Insert the number of your selection:'
    read -r choice
    case $choice in
        1 ) deployment_mode=1
            ;;
        2 ) deployment_mode=2
            ;;
        * ) output 'You did not enter a valid selection.'
            deployment_mode_prompt
    esac
}

deployment_mode_prompt

# Allow reverse proxy
sudo setsebool -P httpd_can_network_connect 1

# OsmAnd port
#sudo semanage port -a -t http_port_t -p tcp 5055
#sudo semanage port -a -t http_port_t -p udp 5055

# Allow rsync
sudo setsebool -P rsync_client 1
sudo setsebool -P rsync_export_all_ro 1 

# Open ports for NGINX
if [ -f '/usr/bin/firewalld-cmd' ]; then
    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --permanent --add-service=https
    sudo firewall-cmd --permanent --add-port=443/udp
    #sudo firewall-cmd --permanent -add-port=5055/tcp
    #sudo firewall-cmd --permanent -add-port=5055/udp
    sudo firewall-cmd --reload
fi

# Setup webroot for NGINX
sudo semanage fcontext -a -t httpd_sys_content_t "$(realpath /srv/nginx)(/.*)?"
sudo mkdir -p /srv/nginx/.well-known/acme-challenge
sudo chmod -R 755 /srv/nginx
if [ "${deployment_mode}" = 1 ]; then
    unpriv curl -s https://raw.githubusercontent.com/Metropolis-Nexus/NGINX-Setup/main/srv/nginx/ads.txt | sudo tee /srv/nginx/ads.txt > /dev/null
    unpriv curl -s https://raw.githubusercontent.com/Metropolis-Nexus/NGINX-Setup/main/srv/nginx/app-ads.txt | sudo tee /srv/nginx/app-ads.txt > /dev/null
    unpriv curl -s https://raw.githubusercontent.com/Metropolis-Nexus/NGINX-Setup/main/srv/nginx/robots.txt | sudo tee /srv/nginx/robots.txt > /dev/null
    sudo chmod 644 /srv/nginx/ads.txt /srv/nginx/app-ads.txt /srv/nginx/robots.txt
fi
sudo restorecon -Rv "$(realpath /srv/nginx)"

# Setup create-session-ticket-keys

sudo mkdir -p /etc/nginx/session-ticket-keys
unpriv curl -s https://raw.githubusercontent.com/Metropolis-Nexus/NGINX-Setup/main/usr/local/bin/create-session-ticket-keys | sudo tee /usr/local/bin/create-session-ticket-keys > /dev/null
sudo semanage fcontext -a -t bin_t /usr/local/bin/create-session-ticket-keys
sudo restorecon /usr/local/bin/create-session-ticket-keys
sudo chmod u+x /usr/local/bin/create-session-ticket-keys

# Setup rotate-session-ticket-keys
unpriv curl -s https://raw.githubusercontent.com/Metropolis-Nexus/NGINX-Setup/main/usr/local/bin/rotate-session-ticket-keys | sudo tee /usr/local/bin/rotate-session-ticket-keys > /dev/null
sudo semanage fcontext -a -t bin_t /usr/local/bin/rotate-session-ticket-keys
sudo restorecon -Rv /usr/local/bin/rotate-session-ticket-keys
sudo chmod u+x /usr/local/bin/rotate-session-ticket-keys

# Download the units
unpriv curl -s https://raw.githubusercontent.com/Metropolis-Nexus/NGINX-Setup/main/etc/systemd/system/etc-nginx-session%5Cx2dticket%5Cx2dkeys.mount | sudo tee /etc/systemd/system/etc-nginx-session\\x2dticket\\x2dkeys.mount > /dev/null
unpriv curl -s https://raw.githubusercontent.com/Metropolis-Nexus/NGINX-Setup/main/etc/systemd/system/create-session-ticket-keys.service | sudo tee /etc/systemd/system/create-session-ticket-keys.service > /dev/null
unpriv curl -s https://raw.githubusercontent.com/Metropolis-Nexus/NGINX-Setup/main/etc/systemd/system/rotate-session-ticket-keys.service | sudo tee /etc/systemd/system/rotate-session-ticket-keys.service > /dev/null
unpriv curl -s https://raw.githubusercontent.com/Metropolis-Nexus/NGINX-Setup/main/etc/systemd/system/rotate-session-ticket-keys.timer | sudo tee /etc/systemd/system/rotate-session-ticket-keys.timer > /dev/null

# Systemd Hardening
sudo mkdir -p /etc/systemd/system/nginx.service.d /etc/systemd/system/certbot-renew.service.d
unpriv curl -s https://raw.githubusercontent.com/Metropolis-Nexus/NGINX-Setup/main/etc/systemd/system/nginx.service.d/override.conf | sudo tee /etc/systemd/system/nginx.service.d/override.conf > /dev/null
unpriv curl -s https://raw.githubusercontent.com/Metropolis-Nexus/NGINX-Setup/main/etc/systemd/system/certbot-renew.service.d/override.conf | sudo tee /etc/systemd/system/certbot-renew.service.d/override.conf > /dev/null
sudo systemctl daemon-reload

# Enable the units
sudo systemctl enable --now etc-nginx-session\\x2dticket\\x2dkeys.mount
sudo systemctl enable --now create-session-ticket-keys.service
sudo systemctl enable --now rotate-session-ticket-keys.timer

# Download NGINX configs
if [ "${deployment_mode}" = 1 ]; then
    unpriv curl -s https://raw.githubusercontent.com/Metropolis-Nexus/NGINX-Setup/main/etc/nginx/nginx.conf | sudo tee /etc/nginx/nginx.conf > /dev/null
    unpriv curl -s https://raw.githubusercontent.com/Metropolis-Nexus/NGINX-Setup/main/etc/nginx/conf.d/default.conf | sudo tee /etc/nginx/conf.d/default.conf > /dev/null
else
    unpriv curl -s https://raw.githubusercontent.com/Metropolis-Nexus/NGINX-Setup/main/etc/nginx/nginx-stream.conf | sudo tee /etc/nginx/nginx.conf > /dev/null
fi

if [ "${deployment_mode}" = 1 ]; then
    sudo mkdir -p /etc/nginx/snippets
    unpriv curl -s https://raw.githubusercontent.com/Metropolis-Nexus/NGINX-Setup/main/etc/nginx/snippets/security.conf | sudo tee /etc/nginx/snippets/security.conf > /dev/null
    unpriv curl -s https://raw.githubusercontent.com/Metropolis-Nexus/NGINX-Setup/main/etc/nginx/snippets/permissions.conf | sudo tee /etc/nginx/snippets/permissions.conf > /dev/null
    unpriv curl -s https://raw.githubusercontent.com/Metropolis-Nexus/NGINX-Setup/main/etc/nginx/snippets/permissions-mic.conf | sudo tee /etc/nginx/snippets/permissions-mic.conf > /dev/null
    unpriv curl -s https://raw.githubusercontent.com/Metropolis-Nexus/NGINX-Setup/main/etc/nginx/snippets/cross-origin-security.conf | sudo tee /etc/nginx/snippets/cross-origin-security.conf > /dev/null
    unpriv curl -s https://raw.githubusercontent.com/Metropolis-Nexus/NGINX-Setup/main/etc/nginx/snippets/proxy.conf | sudo tee /etc/nginx/snippets/proxy.conf > /dev/null
    unpriv curl -s https://raw.githubusercontent.com/Metropolis-Nexus/NGINX-Setup/main/etc/nginx/snippets/htpasswd.conf | sudo tee /etc/nginx/snippets/htpasswd.conf > /dev/null
    unpriv curl -s https://raw.githubusercontent.com/Metropolis-Nexus/NGINX-Setup/main/etc/nginx/snippets/quic.conf | sudo tee /etc/nginx/snippets/quic.conf > /dev/null
    unpriv curl -s https://raw.githubusercontent.com/Metropolis-Nexus/NGINX-Setup/main/etc/nginx/snippets/robots.conf | sudo tee /etc/nginx/snippets/robots.conf > /dev/null
    unpriv curl -s https://raw.githubusercontent.com/Metropolis-Nexus/NGINX-Setup/main/etc/nginx/snippets/universal_paths.conf | sudo tee /etc/nginx/snippets/universal_paths.conf > /dev/null
    sudo mkdir -p /etc/nginx/htpasswd.d
    sudo touch /etc/nginx/htpasswd.d/admin
else
    sudo mkdir -p /etc/nginx/stream.d
    unpriv curl -s https://raw.githubusercontent.com/Metropolis-Nexus/NGINX-Setup/main/etc/nginx/stream.d/upstreams.conf | sudo tee /etc/nginx/stream.d/upstreams.conf > /dev/null
fi
