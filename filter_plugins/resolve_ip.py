#!/usr/bin/env python3

import socket


def resolve_all_ips(host: str) -> list[str]:
    try:
        addr_infos = socket.getaddrinfo(host, None, socket.AF_UNSPEC)
        all_addrs = {info[-1][0] for info in addr_infos}
        return sorted(list(all_addrs))
    except socket.gaierror:
        return []


def resolve_hosts_to_ips(hosts: list[str]) -> list[str]:
    all_addrs: set[str] = set()
    for host in hosts:
        all_addrs.update(resolve_all_ips(host))

    return sorted(list(all_addrs))


class FilterModule(object):
    def filters(self):
        return {
            'resolve_to_ips': resolve_all_ips,
            'resolve_all_hosts': resolve_hosts_to_ips,
        }
