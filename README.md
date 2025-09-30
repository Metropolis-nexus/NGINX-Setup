# NGINX Setup

![ShellCheck](https://github.com/Metropolis-Nexus/NGINX-Setup/actions/workflows/shellcheck.yml/badge.svg)

NGINX configurations meant for deployment on Fedora CoreOS.

**Note:** While it is possible to combine https and stream in a single VM, Metropolis.nexus uses 2 separate VMs to keep the config simple and be more efficient.

## Deployment without Stream

- Install required dependencies: 

```bash
sudo rpm-ostree install certbot nginx policycoreutils-python-utils
sudo reboot
```

- Run `setup.sh`
- Generate a certificate with the `certbot-command` example
- Copy `/etc/nginx/conf.d/default-quic` from the repo and adjust accordingly

## Deployment with Stream

- Fedora's NGINX Stream is broken at the moment. Add upstream's RHEL 10 repo instead:
```
[nginx-mainline]
name=nginx mainline repo
baseurl=http://nginx.org/packages/mainline/centos/10/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
priority=1
```

- Install required dependencies:
```bash
sudo rpm-ostree install certbot nginx policycoreutils-python-utils
sudo reboot
```

- Run `setup.sh`
- Generate a certificate with the `certbot-command` example
- Copy `/etc/nginx/stream.d/default` from the repo and adjust accordingly
