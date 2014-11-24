class ffnord::resources::meta {

  vcsrepo { 
     '/opt/icvpn-scripts/':
       ensure => present,
       provider => git,
       source => "https://github.com/freifunk/icvpn-scripts.git",
       require => [
         Vcsrepo['/var/lib/icvpn-meta/'],
         Package['python-yaml']
       ];
  }

  package {
    'python-yaml':
      ensure => installed;
  }
}

class ffnord::resources::meta::local(
  $local_meta_git
){
  include ffnord::resources::meta

  file { 
    '/usr/local/bin/update-local-meta':
      ensure => file,
      owner => 'root',
      group => 'root',
      mode => '0755',
      source => "puppet:///modules/ffnord/usr/local/bin/update-local-meta";
  }

  cron {
    'update-local-meta':
      command => '/usr/local/bin/update-local-meta',
      user => root,
      minute => '0',
      require => [
        File['/usr/local/bin/update-local-meta']
      ];
  }

  vcsrepo { 
     '/var/lib/local-meta/':
       ensure => present,
       provider => git,
       source => $local_meta_git
  }

  exec {
    'update-local-meta':
      command => '/usr/local/bin/update-local-meta',
      require => [
        Vcsrepo['/var/lib/local-meta/'],
        File['/usr/local/bin/update-local-meta'],
      ];
  }
}

class ffnord::resources::meta::icvpn(){

  include ffnord::resources::meta
  
  vcsrepo { 
     '/var/lib/icvpn-meta/':
       ensure => present,
       provider => git,
       source => "https://github.com/freifunk/icvpn-meta.git";
  }

  file { 
    '/usr/local/bin/update-icvpn-meta':
      ensure => file,
      owner => 'root',
      group => 'root',
      mode => '0755',
      source => "puppet:///modules/ffnord/usr/local/bin/update-icvpn-meta";
  }

  cron {
    'update-icvpn-meta':
      command => '/usr/local/bin/update-icvpn-meta',
      user => root,
      minute => '0',
      require => [
        File['/usr/local/bin/update-icvpn-meta']
      ];
  }

  exec {
    'update-icpvn-meta':
      command => '/usr/local/bin/update-icvpn-meta',
      require => [
        Vcsrepo['/var/lib/icvpn-meta/'],
        File['/usr/local/bin/update-icvpn-meta'],
      ];
  }

  exec {
    'update-meta':
      command => '/usr/local/bin/update-icvpn-meta',
      require => [
        Vcsrepo['/var/lib/icvpn-meta/'],
        File['/usr/local/bin/update-icvpn-meta'],
      ];
  }
}
