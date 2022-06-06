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
- Unlike most Ansible setups, systems are expected to reach out and fetch the
  latest playbooks and run `ansible-playbook` (via `run_ansible.sh`) locally.

## Setup

Only setup.sh is needed locally to begin the setup process. Run the script as a
regular user, passing the 1Password host name and account email address as
arguments:

```sh
% ./setup.sh me.1password.com me@example.com
```

Note that `setup.sh` will install
[1Password CLI2](https://app-updates.agilebits.com/product_history/CLI2) and
expects `/usr/local/bin/op` to be the version 2 CLI.

The setup script will prompt for `sudo`/`doas` credentials when needed. Each
command run is printed out so you know what is prompting for your password. The
setup script will:

- Install Homebrew on macOS
- Install packages needed for Ansible to run successfully
- Install needed Ansible packages from Ansible Galaxy
- Retrieve the 1Password CLI version 2 from upstream and install it
- Authenticate to 1Password
- Fetch the Github SSH key from 1Password
- Check out this repository from Github
- Run `run_ansible.sh`

When including dotfiles, it is expected these playbooks are run first and the
system is rebooted before applying dotfiles.

## Configuration

Configuration facts are all found in `inventory/all.yml`. Facts which I expect
to remain static across all relevant hosts are defined here directly, other
facts are configured in `config` roles.

### `user`

`user` is the username for your local non-root account.

### `timezone`

`timezone` is the timezone to use for your hosts.

### `dns_servers`

`dns_servers` is a list of DNS server IP addresses to configure on each host.

### `ntp_servers`

`ntp_servers` is a list of NTP servers to use in `ntpd.conf(5)` or
`timesyncd.conf`.

### `interfaces`

`interfaces` is a mapping of interface name to interface configuration.

For OpenBSD, `interfaces` maps interface names to lines in the `hostname.if(5)`
file:

```yaml
interfaces:
  rl0:
    - inet autoconf
    - inet6 autoconf
    - up
```

For Linux, `interfaces` maps interface names to basic network config:

```yaml
interfaces:
  eth0:
    ip: '192.168.1.100/24'
    ip6: 'fe80::beef:100/64'
    gateway: 192.168.1.1
```

### `bsd_gateway`

`bsd_gateway` defines a list of default gateways to put in `/etc/mygate` on
OpenBSD systems.

### `pf`

`pf` holds configuration for PF. Used keys are:

#### `anchors`

Maps anchor name to a file to load anchor rules from. Set the file to the empty
string to create an anchor without loading from a file.

#### `lan_interface`

Set the interface name on the LAN side.

#### `martians`

Set to true to allow routing to martian addresses.

#### `nat`

Set to true to enable NAT-related rules. Should only be used when acting as a
router.

#### `tables`

Map table names to a map of table data.

```yaml
tables:
  dns:
    const: false
    persist: true
    file: /etc/pf.tables.d/pf.dns.conf
    entries: []
  ntp:
    const: true
    persist: false
    file: ''
    entries:
      - 129.134.28.123
      - 129.134.29.123
```

#### `variables`

Maps additional PF macros to their value.

### `dyndns_hosts`

`dyndns_hosts` is a list of host namess which the host will send updates for.
The IPv4 and IPv6 addresses to use will be detected using an external service
and the IPv6 address is assumed to have a `/64` netmask.

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

### `networkmanager_config`

`networkmanager_config` defines a hash of `NetworkManager.conf` sections to
a settings hash. Each key of `networkmanager_config` is assumed to be a section
name in `NetworkManager.conf`. Each settings hash under a section is assumed to
be the setting name and value.

### `iptables_rules`

`iptables_rules` is a list of `iptables` rule hashes. Each rule has is passed
directly to the Ansible `iptables` module; see
https://docs.ansible.com/ansible/latest/collections/ansible/builtin/iptables_module.html
for all valid keys and values.

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
  - `groups`: A list of maps. Contains keys `options` for overriding or adding
    DHCP options and `hosts` for designating which hosts are in the group.
  - `hosts`: A map of host name to MAC address and desired static address.

### `rad_config`

`rad_config` defines a basic config for `rad(8)`:

- `dns`: A list of IPv6 DNS server addresses to advertise in each RA.
- `interfaces`: A list of interface names to advertise RAs on.

## Role `vars` files

In some cases, configuration may not be static across all hosts but is far
simpler and cleaner to define as Ansible variables. For these, the relevant
facts are defines in a `vars` file under the relevant role. There are also some
roles which require you to pass variables in.
