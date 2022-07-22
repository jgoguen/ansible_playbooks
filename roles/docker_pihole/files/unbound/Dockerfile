FROM pihole/pihole:latest

RUN \
        apt-get update && \
        apt-get install unbound wget -y && \
        rm -rf /var/lib/apt/lists/* && \
        rm -f /etc/systemd/system/unbound.service.wants/unbound-resolvconf.service && \
        wget -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.root && \
        cp /usr/share/dns/root.key /var/lib/unbound/ && \
        mkdir /var/log/unbound && touch /var/log/unbound/unbound.log && chown -R unbound:unbound /var/log/unbound

COPY service/* /etc/services.d/unbound/
