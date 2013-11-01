# == Class: nepho_railsapp
#
# Full description of class nepho_railsapp here.
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if it
#   has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should not be used in preference to class parameters  as of
#   Puppet 2.6.)
#
# === Examples
#
#  class { nepho_railsapp:
#    servers => [ 'pool.ntp.org', 'ntp.local.company.com' ]
#  }
#
# === Authors
#
# Steve Huff <steve_huff@harvard.edu>
#
# === Copyright
#
# Copyright 2013 President and Fellows of Harvard College
#
class nepho_railsapp (
  $app_name,
  $app_repo,
  $server_name,
  $db_server,
  $db_root_user,
  $db_root_password,
  $db_name,
  $db_user,
  $db_password,
  $db_port,
  $app_port,
  $app_user,
  $app_group,
  $deploy_user,
  $deploy_group,
  $ruby_version,
  $passenger_version,
  $admin_email = 'admin@example.com',
  $s3_bucket = false,
  $s3_access_key = false,
  $s3_secret_key = false,
  $ensure = 'present',
  $instance_role = 'standalone'
) {
  class { 'railsapp':
    appname          => $nepho_railsapp::app_name,
    servername       => $nepho_railsapp::server_name,
    railsuser        => $nepho_railsapp::app_user,
    railsgroup       => $nepho_railsapp::app_group,
    rubyversion      => $nepho_railsapp::ruby_version,
    passengerversion => $nepho_railsapp::passenger_version,
  }

  include rvm
  Rvm_gem {
    ruby_version => $nepho_railsapp::ruby_version,
    require      => Rvm_system_ruby[$nepho_railsapp::ruby_version],
  }

  rvm_gem { 'bundler':
    name   => 'bundler',
    ensure => 'latest',
  }

  rvm_gem { 'capistrano':
    name   => 'capistrano',
    ensure => '2.15.5',
    before => Rvm_gem['rvm-capistrano'],
  }

  rvm_gem { 'rvm-capistrano':
    name   => 'rvm-capistrano',
    ensure => 'latest',
  }

  # put the deploy user in the app group
  augeas { "${nepho_railsapp::deploy_user}_${nepho_railsapp::app_group}_group":
    context => '/files/etc/group',
    changes => "set ${nepho_railsapp::app_group}/user[00] ${nepho_railsapp::deploy_user}",
    onlyif  => "match ${nepho_railsapp::app_group}/user[. = \"${nepho_railsapp::deploy_user}\"] size == 0",
    incl    => '/etc/group',
    lens    => 'Group.lns',
    require => Class['railsapp'],
  }

  # put the apache user in the app group
  augeas { "apache_${nepho_railsapp::app_group}_group":
    context => '/files/etc/group',
    changes => "set ${nepho_railsapp::app_group}/user[00] apache",
    onlyif  => "match ${nepho_railsapp::app_group}/user[. = \"apache\"] size == 0",
    incl    => '/etc/group',
    lens    => 'Group.lns',
    require => Class['railsapp'],
  }

  file { '/root/capistrano-deploy.rb':
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => template('nepho_railsapp/capistrano-deploy.rb.erb'),
  }

  case $::osfamily {
    'amazon': {
      package { 'update-motd':
        ensure => 'present',
      }

      file { '/etc/update-motd.d/90-motd-role':
        ensure  => 'present',
        owner   => 'root',
        group   => 'root',
        mode    => 0755,
        content => template('nepho_railsapp/motd-role.erb'),
        require => Package['update-motd'],
        before  => Exec['run-update-motd'],
        notify  => Exec['run-update-motd'],
      }

      exec { 'run-update-motd':
        path        => '/bin:/sbin:/usr/bin:/usr/sbin',
        command     => 'update-motd',
        logoutput   => 'on_failure',
        refreshonly => true,
      }
    }
    default: {
      notify { "No additional MOTD configuration for '${::osfamily}' platform.": }
    }
  }
}
