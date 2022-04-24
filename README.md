# Ansible Playbooks

This repository contains my Ansible playbooks for setting up a new laptop,
desktop, or server. In contrast to most system configuration setups, some
different assumptions are made here:

- Servers are OpenBSD on the current stable release or CentOS.
- Laptop and desktop clients may be Fedora or macOS.
- Servers are normally accessed using a non-root user.
- Each system is a fresh OS install with a non-root user with `sudo`/`doas`
  privileges already created.
- Roles assigned to machines change rarely, if ever, so there is no automated
  cleanup of old configs or stopping services. So far, the effort and time
  actually expended on manual role changes has not approached the low estimated
  effort of codifying all those rules in Ansible.
- The initial setup script is not intended for unattended use and successfully
  running these playbooks depends on having external Internet connectivity.
- Package installation only ensures the packages are present, upgrades are
  expected to be done manually.
- While running these playbooks, services, including network connectivity, are
  allowed to restart in a disruptive manner if needed.
- Reboots are not done automatically but are expected to be done promptly when
  needed.

## Setup

Only setup.sh is needed locally to begin the setup process. Run the script as a
regular user, passing the 1Password host name and account email address as
arguments:

```sh
% ./setup.sh me.1password.com me@example.com
```

The setup script will prompt for `sudo`/`doas` credentials when needed. Each
command run is printed out so you know what is prompting for your password. The
setup script will:

- Install Homebrew on macOS
- Install packages needed for Ansible to run successfully
- Install needed Ansible packages from Ansible Galaxy
- Retrieve the 1Password CLI from upstream and install it
- Authenticate to 1Password
- Fetch the Ansible vault key and Github SSH key from 1Password
- Check out this repository from Github
- Run `ansible-playbook`

When including dotfiles, it is expected these playbooks are run first and the
system is rebooted before applying dotfiles.

## Playbook organization

Unlike most Ansible setups, systems are expected to reach out and fetch the
latest playbooks and run `ansible-playbook` locally. Additionally, many systems
are expected to be configured using these playbooks and those systems may each
have multiple shared roles. Taken together, the normal Ansible model for
playbooks does not work well. A system such as Chef is normally better suited
for this setup, but Chef is not natively available for OpenBSD and compiling
Ansible and its dependencies can take quite some time on lower-powered or
Raspberry Pi systems.

To accommodate these various needs, playbooks are assigned under two roles:
`config` and `exec`. All playbooks under `config` are expected to only set facts
for later use, they should never make any actual changes to the system. It must
be safe to run the entire `config` role at any time in any state. The `exec`
role is where changes are actually made based on the facts set by the `config`
role. `exec` playbooks must never change facts. The only exception to this is
when it is simpler to express the configuration for a role in a `vars` file and
that configuration is static across all hosts; then the `vars` file in the
`exec` role may hold the configuration instead of setting facts in `config`.

When run, this emulates the Chef two-pass system with API cookbooks fairly well;
the first (`config`) pass sets up resources, the second (`exec`) pass actually
modifies the system. Also like Chef, this setup allows `exec` playbooks to
validate and enforce values which may have been set by multiple other `config`
playbooks.

## Configuration

Configuration facts are all found in `inventory/all.yml`. Facts which I expect
to remain static across all relevant hosts are defined here directly, other
facts are configured in `config` roles.

### `user`

`user` is the username for your local non-root account.

### `unix_groups`

`unix_groups` is a list of UNIX groups to add `user` to.

### `roles`

`roles` defines a list of roles for a specific host. The following roles are
currently defined:

- `backup`: This host will be configured to serve a backup directory over Samba,
  with Time Machine support enabled for macOS clients.
- `desktop`: This host will be a client desktop/laptop system. Setting this
  `false` implies this host will be a server.
- `devel`: This host may be used for development and should have appropriate
  packages installed.
- `dhcpd`: This host will be a DHCP server. OpenBSD `dhcpd` is assumed.
- `dns`: This host will be a DNS server. OpenBSD `unbound` is assumed.
- `docker`: This host will run Docker containers using `docker-compose` and
  systemd units to start containers on boot.
- `gw`: This host will be an Internet gateway. OpenBSD is assumed. This will
  also configure `rad` for SLAAC advertisement.
- `mqttd`: This host will be a MQTT server. Mosquitto on OpenBSD is assumed.
- `storage`: This host will provide storage to other hosts.

### `certbot_hosts`

`certbot_hosts` is a list of host names which the OpenBSD `acme-client` will
attempt to retrieve/renew certificates for.

### `dyndns_hosts`

`dyndns_hosts` is a list of host namess which the host will send updates for.
The IPv4 and IPv6 addresses to use will be detected using an external service
and the IPv6 address is assumed to have a `/64` netmask.

### `packages`

`packages` defines a map of package actions to packages.

- `install`: A list of packages which will be installed. If packages are already
  present, they will not be upgraded to the latest version.
- `remove`: A list of packages which will be removed.
- `snap` A list of hashes defining a Snap name, the channel to install from, and
  whether to allow classic confinement.
  - Example: `[{"name": "1password", "channel": "beta", "classic": false}, {"name": "wesnoth", "channel": "stable", "classic": true}]`
- `flatpak`: A list of Flatpak package identifiers to install. Packages are
  assumed to be available on Flathub.
- `pip`: A list of packages to install from PyPI.
- `npm`: A list of NPM packages to install.

### `coprs`

`coprs` defines a list of hashes defining COPR repositories to enable.

Example: `[{"user": "jgoguen", "name": "universal-ctags"}]` will run
`/usr/bin/dnf copr enable -y jgoguen/universal-ctags`.

### `networkmanager_config`

`networkmanager_config` defines a hash of `NetworkManager.conf` sections to
a settings hash. Each key of `networkmanager_config` is assumed to be a section
name in `NetworkManager.conf`. Each settings hash under a section is assumed to
be the setting name and value.

### `iptables_policies`

`iptables_policies` defines the default policy for the `INPUT`, `FORWARD`, and
`OUTPUT` chains. Only chains in the `filter` table are supported.

### `iptables_rules`

`iptables_rules` is a list of `iptables` rule hashes. Each rule has is passed
directly to the Ansible `iptables` module; see
https://docs.ansible.com/ansible/latest/collections/ansible/builtin/iptables_module.html
for all valid keys and values.

### `bsd_interfaces`

`bsd_interfaces` maps an interface name to a list of lines to put in the
corresponding `hostname.if(5)` file on OpenBSD systems.

### `bsd_gateway`

`bsd_gateway` defines a list of default gateways to put in `/etc/mygate` on
OpenBSD systems.

### `pf_variables`

`pf_variables` defines a mapping of variable names to values to put in
`pf.conf(5)`. Variables defined here may be referenced in `pf_rules` as `$name`.

### `pf_tables`

`pf_tables` maps PF table names to a list of table contents. Tables defined here
may be referenced in `pf_rules` as `&lt;name&gt;`.

### `services`

`services` defines a map from action to service name:

- `start`: Services in this list will be enabled and started.
- `stop`: Services in this list will be stopped and disabled.

### `sysctls`

`sysctls` defines a dictionary mapping sysctl name to value.

### `dhcpd_config`

`dhcpd_config` defines the `dhcpd` configuration:

- `dns`: A list of DNS servers to advertise.
- `domain_name`: The network domain name to advertise.
- `lease`: Defines the DHCP lease times:
  - `default`: The time in seconds for the default DHCP lease length.
  - `max`: The time in seconds for the maximum validity of a DHCP lease.
- `subnets`: Define a list of specific subnets for the DHCP server to advertise.
  Each subnet must map to one interface in `bsd_interfaces`.
  - `base`: The base address of the subnet (e.g. `10.1.0.0`).
  - `subnet`: The subnet mask (e.g. `255.255.255.0`).
  - `router`: The subnet gateway address (e.g. `10.1.0.1`).
  - `start`: The starting address for DHCP leases.
  - `end`: The last address for DHCP leases.
  - `hosts`: A map of host name to MAC address and desired static address.

### `rad_config`

`rad_config` defines a basic config for `rad(8)`:

- `dns`: A list of IPv6 DNS server addresses to advertise in each RA.
- `interface`: The interface to advertise RAs on.

### `doas_rules`

`doas_rules` defines a list of rules to put in `doas.conf(5)`.

### `sudo_config`

`sudo_config` defines the configuration for `sudoers`:

- `defaults_flags`: This defines a list of flags to define in `/etc/sudoers` as
  boolean flags.
- `defaults`: This defines a map of `/etc/sudoers` flags to the intended values.
- `users`: This defines a list of `sudoers` config hashes:
  - `username`: The username for the rule. Start this with `%` to use a group
    name instead of a user name.
  - `from`: Where this `sudoers` rule is valid from.
  - `as_user`: Which user(s) authorized users may act as for this rule.
  - `commands`:
    - `passwd` is a list of commands that may be executed after entering the
      user's password.
    - `nopasswd` is a list of commands the user may execute without entering
      their password.

### `macos_defaults`

`macos_defaults` maps `defaults` CLI domains to a list of setting hashes to
apply within that domain. Each setting hash must contain:

- `key`: The setting name.
- `type`: The type of setting as given to the `defaults` CLI command.
- `value`: The value of the setting.
- `become`: `yes`/`no` whether to become `username` to apply this setting.
  Defaults to `yes` if not given.

### `ntp_servers`

`ntp_servers` is a list of NTP servers to use in `ntpd.conf(5)` or
`timesyncd.conf`.

### `dns_servers`

`dns_servers` defines a list of DNS servers to put in `resolved.conf` for the
`FallbackDNS` setting.

### `unbound_config`

`unbound_config` defines the config for `unbound(8)`. See `inventory/all.yml`
and `roles/exec/unbound/templates/unbound.conf.j2` for setting definitions.
Valid keys for this hash are valid setting names in `unbound.conf(5)`.

## Role `vars` files

In some cases, configuration may not be static across all hosts but is far
simpler and cleaner to define as Ansible variables. For these, the relevant
facts are defines in a `vars` file under the relevant `config` role and is
merged into the main fact set in a task.
