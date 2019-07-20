#!/bin/sh
docker_network="$(ip -o addr show dev eth0| awk '$3 == "inet" {print $4}')"

iptables -F
iptables -X
iptables -Z
#iptables -P INPUT DROP

iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
iptables -A FORWARD -i eth0 -j ACCEPT

iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

iptables -A INPUT -s ${docker_network} -j ACCEPT

openvpn --config /vpn/config/config.ovpn
