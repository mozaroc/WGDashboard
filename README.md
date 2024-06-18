## [WGDashboard](https://github.com/donaldzou/WGDashboard) for [AmneziaWG](https://github.com/amnezia-vpn/amneziawg-linux-kernel-module)

A bit of crap code has been added to the original panel to adapt it to work with the obfuscated version of WireGuard.

### Installation instructions

Tested only with Ubuntu 22.04

#### Install AmneziaWG kernel module

1. Upgrade your system to latest packages including latest available kernel by running 
  apt-get full-upgrade 
After kernel upgrade reboot is required.
2. Ensure that you have source repositories configured for APT - run vi /etc/apt/sources.list and make sure that there is at least one line starting with deb-src is present and uncommented.
3. Install pre-requisites - run 
   sudo apt install -y software-properties-common python3-launchpadlib gnupg2 linux-headers-$(uname -r)
4. sudo add-apt-repository ppa:amnezia/ppa
5. sudo apt-get install -y amneziawg.
6. Create simlinks from awg and awg-quick to wg and wg-quick
   ln -s /usr/bin/awg /usr/bin/wg
   ln -s /usr/bin/awg-quick /usr/bin/wg-quick
7. reboot

#### Install WGDashboard

1. Install pip
   apt -y install python3-pip
2. Install pre-requisites
   pip install gunicorn ifcfg flask flask_qrcode icmplib
3. Clone and install WGDashboard
   cd /
4. git clone https://github.com/mozaroc/WGDashboard.git wgdashboard
5. cd /wgdashboard/src
6. chmod u+x wgd.sh
7. ./wgd.sh install
8. Configure awg server interface 
   cd /wgdashboard
9. chmod u+x awg-gen-config.sh
10. ./awg-gen-config.sh
11.  Create wg-dash systemd unit
   ```
cat << EOF | sudo tee "/etc/systemd/system/wg-dash.service"
[Unit]
After=syslog.target network-online.target
ConditionPathIsDirectory=/etc/wireguard
[Service]
Type=forking
User=root
Group=root
PIDFile=/wgdashboard/src/gunicron.pid
WorkingDirectory=/wgdashboard/src
ExecStart=/usr/bin/env gunicorn --access-logfile /wgdashboard/src/log/access.log --error-logfile /wgdashboard/src/log/error.log 'dashboard:run_dashboard()' --pid /wgdashboard/src/gunicron.pid
PrivateTmp=true
Restart=no

[Install]
WantedBy=multi-user.target

EOF
```
12. Create WGsashboard config
```
cat << EOF | sudo tee "/wgdashboard/src/wg-dashboard.ini"
[Account]
username = admin
password = 8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918

[Server]
wg_conf_path = /etc/wireguard
app_ip = MAIN_IP_OF_YOUR_SERVER
app_port = 10085
auth_req = true
version = v3.1
dashboard_refresh_interval = 60000
dashboard_sort = status
dashboard_theme = light

[Peers]
peer_global_dns = 1.1.1.1
peer_endpoint_allowed_ip = 0.0.0.0/0
peer_display_mode = grid
remote_endpoint = MAIN_IP_OF_YOUR_SERVER
peer_mtu = 1342
peer_keep_alive = 21

EOF

```
#### Configure firewall

```
1. Allow panel port(see app_port in /wgdashboard/src/wg-dashboard.ini)
ufw allow 10085/tcp
2. Allow awg server port (see ListenPort in /etc/amnezia/amneziawg/wg0.conf)
ufw allow 52853/udp
3. Enable routing
   edit  /etc/ufw/sysctl.conf
   uncomment three lines:

   net/ipv4/ip_forward=1
   net/ipv6/conf/default/forwarding=1
   net/ipv6/conf/all/forwarding=1

4. Set default policy for forwarding
   edit /etc/default/ufw
   set -   DEFAULT_FORWARD_POLICY="ACCEPT"

5. Add NAT rules for awg clients
   edit /etc/ufw/before.rules
   add all lines to the start of document:
   
   # NAT table rules
   *nat
    :POSTROUTING ACCEPT [0:0]

   # Forward traffic through eth0 - Change to match you out-interface
   -A POSTROUTING -s 10.90.90.0/24 -o eth0 -j MASQUERADE

   # don't delete the 'COMMIT' line or these nat table rules won't
   # be processed
   COMMIT
```

start awg interface

```
awg-quic up wg0
```

start WGDashboard

```
systemctl daemon-reload
systemctl enable wg-dash --network
```




 

