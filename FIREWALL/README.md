/usr/local/bin/aegis-firewall-secure.sh
/etc/systemd/system/aegis-firewall-lockdown.service
# Иzinleri tazele
sudo chmod 700 /usr/local/bin/aegis-firewall-secure.sh

# SELinux bağlamını tüm /etc/firewalld için baştan aşağı onar
sudo restorecon -Rv /etc/firewalld/

# Servisi yeniden başlat
sudo systemctl daemon-reload
sudo systemctl restart aegis-firewall-lockdown.service
