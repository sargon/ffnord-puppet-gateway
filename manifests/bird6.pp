class ffnord::bird6 (
  $router_id = $ffnord::params::router_id,
  $icvpn_as  = $ffnord::params::icvpn_as
) inherits ffnord::params {

  require ffnord::resources::repos
 
  ffnord::monitor::nrpe::check_command {
    "bird6":
      command => '/usr/lib/nagios/plugins/check_procs -w 1:1 -c 1:1 -C bird6';
  }

  package { 
    'bird6':
      ensure => installed,
      require => [
        File['/etc/apt/preferences.d/bird'],
        Apt::Source['debian-backports']
      ];
  }
 
  file {
    '/etc/bird/bird6.conf.d/local/':
      ensure => directory,
      mode => "0755",
      owner => root,
      group => root,
      require => File['/etc/bird/bird6.conf.d/'];
    '/etc/bird/bird6.conf.d/':
      ensure => directory,
      mode => "0755",
      owner => root,
      group => root,
      require => File['/etc/bird/bird6.conf'];
    '/etc/bird/':
      ensure => directory,
      mode => '0755';
    '/etc/apt/preferences.d/bird':
      ensure => file,
      mode => "0644",
      owner => root,
      group => root,
      source => "puppet:///modules/ffnord/etc/apt/preferences.d/bird";
    '/etc/bird/bird6.conf':
      ensure => file,
      mode => "0644",
      content => template("ffnord/etc/bird/bird6.conf.erb"),
      require => [Package['bird6'],File['/etc/bird/']];
    '/etc/bird6.conf':
      ensure => link,
      target => '/etc/bird/bird6.conf',
      require => File['/etc/bird/bird6.conf'],
      notify => Service['bird6'];
  } 

  service {
    'bird6':
      ensure => running,
      enable => true,
      hasstatus => false,
      restart => "/usr/sbin/birdc6 configure",
      require => Package['bird6'],
      subscribe => File['/etc/bird/bird6.conf'];
  }

  ffnord::firewall::service { "bird6":
    ports  => ['179'],
    protos => ['tcp'],
    chains => ['mesh']
  }

}

define ffnord::bird6::mesh (
  $mesh_code,

  $mesh_ipv4_address,
  $mesh_ipv6_address,
  $mesh_peerings, # YAML data file for local peerings

  $icvpn_as,

  $site_ipv6_prefix,
  $site_ipv6_prefixlen,
) {

  include ffnord::bird6

  file_line { "bird6-${mesh_code}-include":
    path => '/etc/bird/bird6.conf',
    line => "include \"/etc/bird/bird6.conf.d/${mesh_code}.conf\";",
    require => File['/etc/bird/bird6.conf'],
    notify  => Service['bird6'];
  }

  file { 
    "/etc/bird/bird6.conf.d/local/direct_${mesh_code}.inc":
      owner => "root",
      group => "root",
      mode => "0644",
      content => "if (net ~ [ ${site_ipv6_prefix}/$site_ipv6_prefixlen{48,64} ]) then return false;",
      require => [
        File['/etc/bird/bird6.conf.d/local/'],
        Package['bird6']
      ],
      before  => File['/etc/bird/bird6.conf'];
    "/etc/bird/bird6.conf.d/local/network_${mesh_code}.inc":
      owner => "root",
      group => "root",
      mode => "0644",
      content => "if (net ~ [ ${site_ipv6_prefix}/48{48,64} ]) then return false;",
      require => [
        File['/etc/bird/bird6.conf.d/local/'],
        Package['bird6']
      ],
      before  => File['/etc/bird/bird6.conf'];
    "/etc/bird/bird6.conf.d/${mesh_code}.conf":
      mode => "0644",
      content => template("ffnord/etc/bird/bird6.interface.conf.erb"),
      require => [
        File['/etc/bird/bird6.conf.d/'],
        Package['bird6']
      ],
      notify  => [
        File_line["bird6-${mesh_code}-include"],
        Service['bird6']
      ];
  }

  # TODO let meta script`o`matic generate neighbor files
}

define ffnord::bird6::icvpn (
  $icvpn_as,
  $icvpn_ipv4_address,
  $icvpn_ipv6_address,
  $icvpn_exclude_peerings = [],

  $tinc_keyfile,
  ){

  include ffnord::bird6
  include ffnord::resources::meta::icvpn

  $icvpn_name = $name

  class { 'ffnord::tinc': 
    tinc_name    => $icvpn_name,
    tinc_keyfile => $tinc_keyfile,

    icvpn_ipv4_address => $icvpn_ipv4_address,
    icvpn_ipv6_address => $icvpn_ipv6_address,

    icvpn_peers  => $icvpn_peerings;
  }

  file_line { 
    "icvpn-template":
      path => '/etc/bird/bird6.conf',
      line => 'include "/etc/bird/bird6.conf.d/icvpn-template.conf";',
      require => File['/etc/bird/bird6.conf'],
      notify  => Service['bird6'];
    "icvpn-include":
      path => '/etc/bird/bird6.conf',
      line => 'include "/etc/bird/bird6.conf.d/icvpn-peers.conf";',
      require => [
        File['/etc/bird/bird6.conf'],
        Class['ffnord::resources::meta::icvpn']
      ],
      notify  => Service['bird6'];
  } 

  ffnord::resources::ffnord::field {
    "ICVPN": value => '1';
    "ICVPN_EXCLUDE": value => "${icvpn_exclude_peerings}";
  }

  # Process meta data from tinc directory
  file { "/etc/bird/bird6.conf.d/icvpn-template.conf":
    mode => "0644",
    content => template("ffnord/etc/bird/bird6.icvpn-template.conf.erb"),
    require => [ 
      File['/etc/bird/bird6.conf.d/'],
      Package['bird6'],
      Class['ffnord::tinc'],
    ],
    notify  => [
      Service['bird6'],
      File_line['icvpn-include'],
      File_line['icvpn-template']
    ];
  } 
}
