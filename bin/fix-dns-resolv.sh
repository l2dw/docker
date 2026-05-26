# DNS
sudo sed -i 's/^#DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
sudo systemctl restart systemd-resolved
# sudo systemctl disable systemd-resolved
sudo rm /etc/resolv.conf

sudo tee /etc/resolv.conf << EOF > /dev/null
nameserver ${NAMESERVER1}
nameserver ${NAMESERVER2}
nameserver ${NAMESERVER3}
search ${INFRA_NAME} ${INFRA_NAME}.${INFRA_DOMAIN} ${SEARCH_DOMAIN}
EOF
