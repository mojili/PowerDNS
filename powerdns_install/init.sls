#### Pdns server installation state
# https://repo.powerdns.com/
 
{% set config = pillar.get('nodes_info', {}) %}

add_pdns_repo:
  cmd.run:
     - name: echo "deb [arch=amd64] http://repo.powerdns.com/debian bullseye-auth-46 main" > /etc/apt/sources.list.d/pdns.list   

app_preferences:
  file.managed:
    - name: /etc/apt/preferences.d/pdns
    - source: salt://powerdns_install/files/pdns

#install_key:
#  cmd.run:
#     - name: curl https://repo.powerdns.com/FD380FBB-pub.asc | sudo apt-key add -
# get the key like this "wget https://repo.powerdns.com/FD380FBB-pub.asc" and copy content to ../file/pdns.asc

install_key:
  file.managed:
    - name: /tmp/pdns.asc
    - source: salt://powerdns_install/files/pdns.asc

add_key:
  cmd.run:
     - name: sudo apt-key add /tmp/pdns.asc   

remove_keyfile:
  file.absent:
    - name: /tmp/pdns.asc

update_pdns_reposiroty:
  cmd.run:
    - name: "apt-get update -y"

install_pdns_server:
  pkg.installed:
    - pkgs:
       - pdns-server
       - dnsutils

create_dir_structure:
  file.directory:
    - name: /etc/powerdns/configs/
    - makedirs: True

touch_config_file:
   file.managed:
    - name: /etc/powerdns/configs/named.conf.local

named.conf:
  file.managed:
    - name: /etc/powerdns/named.conf
    - source: salt://powerdns_install/files/named.conf

pdns.conf:
  file.managed:
    - name: /etc/powerdns/pdns.conf
    - source: salt://powerdns_install/files/pdns.conf

set_webserver-address:
  cmd.run:
    - name: "sed -i  's/webserver_ip/{{ config['server_variables'][grains['nodename']]['ip'] }}/g' /etc/powerdns/pdns.conf"

bind.conf:
  file.managed:
    - name: /etc/powerdns/pdns.d/bind.conf
    - source: salt://powerdns_install/files/bind.conf

pdns.service:
  file.managed:
    - name: /lib/systemd/system/pdns.service
    - source: salt://powerdns_install/files/pdns.service

daemon_reload_for_pdns:
  module.run:
    - name: service.systemctl_reload
    - onchanges:
      - file: /lib/systemd/system/pdns.service

/var/lib/powerdns:
  file.directory:
    - user: pdns

pdns-start:
  service.running:
    - name: pdns.service
    - restart: True
    - enable: True

pdns-restart:
  cmd.run:
    - name: systemctl restart pdns.service

#### Syslog Management

/etc/rsyslog.conf:
  file.managed:
    - source: salt://general_settings/files/rsyslog.conf

rsyslog-restart:
  service.running:
    - name: rsyslog.service
    - restart: True
    - enable: True

#### Hold Packages

hold_pkgs:
 cmd.run:
    - name: sudo apt-mark hold pdns-server pdns-backend-bind
