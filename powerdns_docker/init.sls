#!jinja|yaml|gpg
{% set app_name = "powerdns" %}
{% set container_name = "pdns" %}
{% set tag_name = pillar['tag_name'] %}
{% set config = pillar.get('nodes_info', {}) %}
{% set registry_url = 'harbor.digicdn.dev:20443' %}
{% set repo = 'powerdns-docker' %}
{% set reg_harbor = pillar.get('reg_harbor', {}) %}
{% if grains['nodename'] == 'stage06' or grains['nodename'] == 'stage07' %}
  {% set NAME_SERVER_1 = '172.30.70.12' %}
  {% set NAME_SERVER_2 = '172.30.70.14' %}
{% elif grains.id in salt['pillar.get']('master:nodegroups:popsite', []) %}
  {% set NAME_SERVER_1 = '8.8.8.8' %}
  {% set NAME_SERVER_2 = '1.1.1.1' %}
{% endif %}


docker_login:
  cmd.run:
    - name: "echo \"$password\" | docker login -u {{ reg_harbor['reg_user'] }} --password-stdin {{ registry_url }}"
    - env:
      - password: {{ reg_harbor['reg_pass'] }}

{% for dir in ['pdns.d', 'configs'] %}
create_{{ dir }}:
  file.directory:
    - name: /etc/powerdns/{{ dir }}/
    - makedirs: True
{% endfor %}

touch_config_file:
   file.managed:
    - name: /etc/powerdns/configs/named.conf.local

named.conf:
  file.managed:
    - name: /etc/powerdns/named.conf
    - source: salt://powerdns_docker/files/named.conf

pdns.conf:
  file.managed:
    - name: /etc/powerdns/pdns.conf
    - source: salt://powerdns_docker/files/pdns.conf

set_webserver-address:
  cmd.run:
    - name: "sed -i 's/webserver_ip/{{ config['server_variables'][grains['nodename']]['ip'] }}/g' /etc/powerdns/pdns.conf"

bind.conf:
  file.managed:
    - name: /etc/powerdns/pdns.d/bind.conf
    - source: salt://powerdns_docker/files/bind.conf

/var/lib/powerdns:
  file.directory:
    - makedirs: True

###### Syslog Management

/etc/rsyslog.conf:
  file.managed:
    - source: salt://general_settings/files/rsyslog.conf

rsyslog-restart:
  cmd.run:
    - name: 'systemctl restart rsyslog.service'

############

stop_remove_container:
  docker_container.absent:
    - force: true
    - names:
      - {{ container_name }}

{{ container_name }}:
  docker_container.running:
    - image: {{ registry_url }}/edge-services/sysops/powerdns-docker/{{ app_name }}:{{ tag_name }}
    - network_mode: host
    - restart_policy: always
    - log_driver: syslog
    - log_opt:
      - syslog-facility: local0
    - binds:
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
      - /etc/powerdns/:/etc/powerdns/
      - /var/lib/powerdns:/var/lib/powerdns
      - /var/run/pdns/:/var/run/pdns/
    - dns:
      - {{ NAME_SERVER_1 }}
      - {{ NAME_SERVER_2 }}

#slack-success:
#  slack.post_message:
#    - message: 'powerdns-docker version {{ tag_name }} has been deployed successfully on {{ grains['nodename'] }}.'
#    - webhook: 'http://hooks.slack.com/services/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'
#    - require:
#      - docker_container: {{ container_name }}

slack-fail:
  slack.post_message:
    - message: 'powerdns-docker {{ tag_name }} deployment has been failed on {{ grains['nodename'] }}.'
    - webhook: 'http://hooks.slack.com/services/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'
    - onfail:
      - docker_container: {{ container_name }}

{%- if not salt['file.file_exists']('/var/lib/powerdns/bind-dnssec-db.sqlite3') %}

create_bind_db:
  cmd.run: 
    - name: 'docker exec pdns pdnsutil create-bind-db /var/lib/powerdns/bind-dnssec-db.sqlite3'

{% endif %}

enable_dnssec_db_configuration:
  cmd.run:
    - name: "sed -i 's|^.*bind-dnssec-db=.*$|bind-dnssec-db=/var/lib/powerdns/bind-dnssec-db.sqlite3|g' /etc/powerdns/pdns.d/bind.conf"

enable_dnssec_db_journal_configuration:
  cmd.run:
    - name: "sed -i 's|^.*bind-dnssec-db-journal-mode=.*$|bind-dnssec-db-journal-mode=WAL|g' /etc/powerdns/pdns.d/bind.conf"

pdns_restart:
  cmd.run:
    - name: 'docker restart pdns'

docker_logout_{{ app_name }}:
  cmd.run:
    - name: "docker logout {{ registry_url }}"
