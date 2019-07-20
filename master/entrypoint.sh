#!/bin/sh

#Init
echo 'nameserver 127.0.0.1' > /etc/resolv.conf
cat /vpn/config/dnsmasq.conf > /etc/dnsmasq.conf
cat /vpn/config/rt_tables > /etc/iproute2/rt_tables
chmod +x /vpn/config/checkpsw.sh
dnsmasq

iptables -F
iptables -X
iptables -Z

iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j MASQUERADE
iptables -A FORWARD -p tcp -i tun0 -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT


# For home network
## Setup home dns to line out-1
ip route add 172.16.2.3 via 172.16.106.254

## Setup the ipset
ipset -N homelist iphash

iptables -t mangle -N homemark
iptables -t mangle -C OUTPUT -j homemark || iptables -t mangle -A OUTPUT -j homemark
iptables -t mangle -C PREROUTING -j homemark || iptables -t mangle -A PREROUTING -j homemark
iptables -t mangle -A homemark -m set --match-set homelist dst -j MARK --set-mark 0xffff
ip rule add fwmark 0xffff table hometable
ip route add default via 172.16.106.254 table hometable
iptables -I FORWARD -o eth1 -j ACCEPT
iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE

## Route list for home network
ipset add homelist 10.10.10.10/24


# For work network
## Setup work dns to line out-2

ip route add 10.43.1.9 via 172.16.107.254

## Setup the ipset
ipset -N worklist iphash

iptables -t mangle -N workmark
iptables -t mangle -C OUTPUT -j workmark || iptables -t mangle -A OUTPUT -j workmark
iptables -t mangle -C PREROUTING -j workmark || iptables -t mangle -A PREROUTING -j workmark
iptables -t mangle -A workmark -m set --match-set worklist dst -j MARK --set-mark 0xfffe
ip rule add fwmark 0xfffe table worktable
ip route add default via 172.16.107.254 table worktable
iptables -I FORWARD -o eth2 -j ACCEPT
iptables -t nat -A POSTROUTING -o eth2 -j MASQUERADE

# Start openvpn proc
openvpn --config /vpn/config/config.ovpn
