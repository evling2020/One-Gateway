你是否想过？我想同时多个网络，比如家庭网络和工作网络，而且随时随地都可以，我不想来回切换线路，用一个统一的网关进行管理可好，还能根据域名动态转发数据，设置特定IP网段走特定线路？那么小编今天带来一套方法，看又没引起你的兴趣。

## 场景设定
该节场景纯属虚构，各位需根据实际调整。
### 家庭网
- 域名：home.com
- 内部域名服务器：172.16.2.3
- 内部一测试用的IP：10.10.10.10

### 工作网
- 域名：work.com
- 内部域名服务器：10.43.1.9

## 环境需求
这里以`OS X`为例。小编的主机是没直接联网的，可以屏蔽一部分来自局域网的恶意攻击威胁。完工之后你也可以，宿主机连接虚拟机VPN后间接联网，还便于流量访控。
- 宿主机：macOS Mojave 10.14.5
- 虚拟机：Debian 10
- 两张网卡：一张桥接主机、一张`host only`
- 软件环境：docker及docker-compose

## 准备就绪
下面就来解读该仓库文件核心内容。
- `Dockerfiles`存放了对外出口openvpn线路和对内统一网关的Openvpn服务的Dockerfile文件
- `master`存放了对内服务的必备配置及数据文件
- `outboard-1`存放了家庭线路的配置文件及数据
- `outboard-2`存放了工作线路的配置文件及数据

各位如需增加线路，可以照着目录克隆并修改。仓库里的所有配置都需要各位结合实际更改，不然无法使用。

### 定义docker网络
```
networks:
in:
ipam:
config:
- subnet: 172.16.105.0/24
gateway: 172.16.105.1
out-1:
ipam:
config:
- subnet: 172.16.106.0/24

out-2:
ipam:
config:
- subnet: 172.16.107.0/24
```
- 172.16.105.0/24用于对接用户终端
- 172.16.106.0/24用于家庭网的对接
- 172.16.107.0/24用于工作网的对接

### 定义容器
```
outboard-1:
networks:
out-1:
ipv4_address: 172.16.106.254
```
去往家庭线路的数据转发至172.16.106.254即可。

```
outboard-2:
networks:
out-2:
ipv4_address: 172.16.107.254
```
同理，去往工作线路的数据转发至172.16.107.254即可。

```
master:
networks:
in:
ipv4_address: 172.16.105.3
out-1:
ipv4_address: 172.16.106.3
out-2:
ipv4_address: 172.16.107.3
ports:
- "1194:1194/tcp"
```
master容器分别联入106和107段，并对外映射1194端口。

### dnsmasq配合ipset基于域名归类流量
```
server=/.work.com/10.43.1.9#53
ipset=/.work.com/worklist
server=/.home.com/172.16.2.3#53
ipset=/.home.com/homelist
```
以work.com结尾的子域名通过10.43.1.9进行域名解析，并加入worklist集合，便于iptables对其实施策略。家庭网络标记同理。

### 具体策略设置
进入`master/entrypoint.sh`，注意，容器启动不了记得对`entrypoint.sh`添加权限。

定义路由表`master/rt_table`，在文件末尾跟上如下内容，有就别跟了。
```
99    hometable
100    worktable
```

`master/entrypoint.sh`
对内流量的伪装
```
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j MASQUERADE
iptables -A FORWARD -p tcp -i tun0 -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
```

```
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
```
对家庭流量的控制，优先对内部域名服务器172.16.2.3走家庭线路，自定义了10.10.10.10/24走家庭线路。

工作网流量策略同理。

## 写在后面
一次构建，一直受益，致敢于折腾的你～，如果喜欢，记得关注我哦，公众号：`恋娱安`

## 责任声明
- 本文不得用于实施违法乱纪行径，否则后果自负。
- 如有侵权，请联系josephmeade@protonmail.com告知删除。
