# NGINX Setup

![ShellCheck](https://github.com/Metropolis-Nexus/NGINX-Setup/actions/workflows/shellcheck.yml/badge.svg)

NGINX configurations meant for deployment on Fedora CoreOS.

## Deployment without Stream

- Install required dependencies: 

```bash
sudo rpm-ostree install certbot nginx policycoreutils-python-utils
sudo reboot
```

- Run `setup.sh`
- Generate a certificate with the `certbot-command` example
- Copy `/etc/nginx/conf.d/nginx.citadel.chi01.metropolis.nexus/default-quic.conf` from the repo to `/etc/nginx/conf.d/default-quic.conf` and adjust accordingly

## Deployment with Stream

- Fedora's NGINX Stream SSL termination is broken at the moment. Add upstream's RHEL 10 repo if you need a workaround:
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

- If you use upstream's RHEL 10 repo, run:

```bash
sudo rpm-ostree install certbot nginx policycoreutils-python-utils
sudo reboot
```

- Otherwise, run:

```bash
sudo rpm-ostree install certbot nginx-mod-stream policycoreutils-python-utils
sudo reboot
```

- Run `setup.sh`
- Generate a certificate with the `certbot-command` example
- Adjust `/etc/nginx/stream.d/upstreams.conf` accordingly

# headers-more Notes

## add_header Interations

Neither `more_set_headers` nor `more_clear_headers` will override a header set by `add_header`. Take the following 2 examples:

```
add_header X-XSS-Protection "0";
more_set_headers "X-XSS-Protection: 1; mode=block";
```

```
add_header X-XSS-Protection "0";
more_clear_headers X-XSS-Protection;
more_set_headers "X-XSS-Protection: 1; mode=block";
```

Both will result in the client getting both `X-XSS-Protection: 0` and `X-XSS-Protection: 1; mode=block` in the reply. To only get `X-XSS-Protection: 1; mode=block`, the following must be used:

```
more_set_headers "X-XSS-Protection: 0";
more_clear_headers X-XSS-Protection;
more_set_headers "X-XSS-Protection: 1; mode=block";
```

`add_header` will not override or undo any headers set by `more_set_headers` in the previous configuration level. For example:

```
add_header X-XSS-Protection "1";
more_set_headers "X-XSS-Protection: 0";

location / {
    add_header X-XSS-Protection "1; mode=block";
}
```

The client will get both `X-XSS-Protection: 0` and `X-XSS-Protection: 1; mode=block`. It will not get `X-XSS-Protection: 1`, however.