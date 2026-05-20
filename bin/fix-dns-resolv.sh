# DNS
sudo sed -i 's/^#DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
sudo systemctl restart systemd-resolved
# sudo systemctl disable systemd-resolved

sudo tee /etc/resolv.conf << EOF > /dev/null
nameserver 192.168.124.175
nameserver 192.168.124.2
nameserver 192.168.124.3
search ocrx.arbutus-cloud arbutus ocrx.arbutus.cloud
EOF
