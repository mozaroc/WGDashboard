#!/bin/bash

set -xe

export SERVER_NAME="serverwg"
export INTERFACE_WG="wg0"

sudo mkdir -p /etc/amnezia/amneziawg/keys ;

wg genkey | sudo tee "/etc/amnezia/amneziawg/keys/server.key" | \
wg pubkey | sudo tee "/etc/amnezia/amneziawg/keys/server.key.pub";

echo
echo "CREATING THE SERVER CONFIG"
echo

DEFAULT_INTERFACE="$(ip -o -4 route show to default | awk '{print $5}')"
MAIN_IP="$(hostname -I | cut -d' ' -f1)"

PRIVATE_KEY=$(sudo cat /etc/amnezia/amneziawg/keys/server.key)

PORT=$(shuf -i 52800-53000 -n1)

J_C=$(shuf -i 7-15 -n1)
J_MIN=$(shuf -i 35-65 -n1)
J_MAX=$(shuf -i 800-950 -n1)
S_1=$(shuf -i 50-70 -n1)
S_2=$(shuf -i 130-150 -n1)
H_1=$(shuf -i 1006457265-1206457265 -n1)
H_2=$(shuf -i 239455488-259455488 -n1)
H_3=$(shuf -i 1109847463-1309847463 -n1)
H_4=$(shuf -i 1546644382-1746644382 -n1)

cat << EOF | sudo tee "/etc/amnezia/amneziawg/${INTERFACE_WG}.conf"
[Interface]
Address = 10.90.90.1/24
ListenPort = ${PORT}
PrivateKey = ${PRIVATE_KEY}
Jc = ${J_C}
Jmin = ${J_MIN}
Jmax = ${J_MAX}
S1 = ${S_1}
S2 = ${S_2}
H1 = ${H_1}
H2 = ${H_2}
H3 = ${H_3}
H4 = ${H_4}

EOF

sudo chmod 600 "/etc/amnezia/amneziawg/${INTERFACE_WG}.conf" "/etc/amnezia/amneziawg/keys/server.key"

echo
echo "ACTIVATING WIREGUARD SERVICE"
echo

sudo wg-quick up "${INTERFACE_WG}"
sudo wg show "${INTERFACE_WG}"

echo
echo "ENABLE WIREGUARD SERVICE AT BOOT"
echo

sudo systemctl enable awg-quick@wg0


chmod -R 755 /etc/amnezia/amneziawg

cat << EOF | sudo tee "/etc/systemd/system/wg-dash.service"
[Unit]
After=syslog.target network-online.target
ConditionPathIsDirectory=/etc/amnezia/amneziawg

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

cat << EOF | sudo tee "/wgdashboard/src/wg-dashboard.ini"
[Account]
username = admin
password = 8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918

[Server]
wg_conf_path = /etc/amnezia/amneziawg
app_ip = 0.0.0.0
app_port = 10085
auth_req = true
version = v3.1
dashboard_refresh_interval = 60000
dashboard_sort = status
dashboard_theme = light

[Peers]
peer_endpoint_allowed_ip = 0.0.0.0/0
peer_display_mode = grid
remote_endpoint = ${MAIN_IP}
peer_keep_alive = 21


EOF

systemctl daemon-reload

systemctl enable wg-dash --now
