# NGINX Setup

![ShellCheck](https://github.com/Metropolis-Nexus/NGINX-Setup/actions/workflows/shellcheck.yml/badge.svg)

NGINX configurations meant for deployment on Fedora CoreOS.

## Deployment without Stream

- Install required dependencies: 

```bash
sudo rpm-ostree install certbot nginx nginx-mod-headers-more nginx-mod-modsecurity policycoreutils-python-utils
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
```

- Otherwise, run:

```bash
sudo rpm-ostree install certbot nginx nginx-mod-stream policycoreutils-python-utils
```

- For mixed deployments not using upstream's RHEL 10 repo, add these additional modules:

```bash
sudo rpm-ostree install nginx-mod-headers-more nginx-mod-modsecurity
```

- Reboot

```bash
sudo reboot
```

- Run `setup.sh`
- Generate a certificate with the `certbot-command` example
- Adjust `/etc/nginx/stream.d/upstreams.conf` accordingly

# Notes

## `more_set_headers` and `add_header` Interactions

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

## headers-more Limitations

The official documentation mentions some limitations with the headers-more module [here](https://github.com/openresty/headers-more-nginx-module?tab=readme-ov-file#limitations).

While the official documentation states that the `Connection` cannot be removed, in practice, it also cannot be set by the module.

Due to the phases that the headers-more module run in, not all NGINX variables are available to it. This is more so the case with `more_set_input_headers` than `more_clear_headers`, as it runs in the "rewrite tail" phase instead of "output-header-filter". For example:

```
auth_request           /outpost.goauthentik.io/auth/nginx;
error_page             401 = @goauthentik_proxy_signin;
auth_request_set       $auth_cookie $upstream_http_set_cookie;
more_set_headers -a    "Set-Cookie: $auth_cookie";

auth_request_set       $authentik_username $upstream_http_x_authentik_username;
more_set_input_headers "Remote-User: $authentik_username";
```

Here, `more_set_headers` has access to the `$auth_cookie` variable set by `auth_request_set`, so the `Set-Cookie` header will be set correctly. However, `more_set_input_headers` does not have access to the `$authentik_username` set by `auth_request_set`, so the proxied server will not receive the correct `Remote-User` header.

Due to the lack of intuitiveness, this repository will limit using variables with headers-more, especially with the `more_set_input_headers` directive.