class ffnord::named () {

  include ffnord::resources::meta::icvpn

  ffnord::monitor::nrpe::check_command {
    "named":
      command => '/usr/lib/nagios/plugins/check_procs -c 1:1 -w 1:1 -C named';
  }

  package {
    'bind9':
      ensure => installed;
  }

  service {
    'bind9':
      ensure => running,
      enable => true,
      hasrestart => true,
      restart => '/usr/sbin/rndc reload',
      require => [
        Package['bind9'],
        File['/etc/bind/named.conf.options'],
        File_line['icvpn-meta'],
        Class['ffnord::resources::meta::icvpn']
      ]
  }

  file {
    '/etc/bind/named.conf.options':
      ensure  => file,
      source  => "puppet:///modules/ffnord/etc/bind/named.conf.options",
      require => [Package['bind9']],
      notify  => [Service['bind9']];
  }

  file_line {
    'icvpn-meta':
       path => '/etc/bind/named.conf',
       line => 'include "/etc/bind/named.conf.icvpn-meta";',
       before => Class['ffnord::resources::meta'],
       require => [
         Package['bind9']
       ];
  }

  ffnord::firewall::service { 'named':
    chains => ['mesh'],
    ports  => ['53'],
    protos => ['udp','tcp'];
  }
}


define ffnord::named::mesh (
  $mesh_ipv4_address,
  $mesh_ipv4_prefix,
  $mesh_ipv4_prefixlen,
  $mesh_ipv6_address,
  $mesh_ipv6_prefix,
  $mesh_ipv6_prefixlen
) {

 include ffnord::named

 $mesh_code = $name

 # Extent the listen-on and listen-on-v6 lines in the options block
 exec { "${name}_listen-on":
   command => "/bin/sed -i -r 's/(listen-on .*)\\}/\\1 ${mesh_ipv4_address};}/' /etc/bind/named.conf.options",
   require => File['/etc/bind/named.conf.options'];
 }
 
 exec { "${name}_listen-on-v6":
   command => "/bin/sed -i -r 's/(listen-on-v6 .*)\\}/\\1 ${mesh_ipv6_address};}/' /etc/bind/named.conf.options",
   require => File['/etc/bind/named.conf.options'];
 }
}
