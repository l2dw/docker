# DNS
## test if UPDATE_DNS_RESOLVERS is set to true in .env
if [ "${UPDATE_DNS_RESOLVERS}" != "true" ] && [ "${UPDATE_DNS_RESOLVERS}" != "1" ]; then
    echo "UPDATE_DNS_RESOLVERS is not set to true in .env, skipping DNS resolution fix"
    exit 0
fi

sudo sed -i 's/^#DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
sudo systemctl mask systemd-resolved
sudo rm -f /etc/resolv.conf
sudo tee /etc/resolv.conf << EOF > /dev/null
nameserver ${EXTERNAL_IP}
nameserver ${GATEWAY_IP}
nameserver 8.8.8.8
search ${INFRA_NAME}.${INFRA_DOMAIN} ${INFRA_NAME}.${INFRA_DOMAIN/-/.} ${SEARCH_DOMAIN}
EOF

# Confirm the DNS configuration:
cat /etc/resolv.conf

