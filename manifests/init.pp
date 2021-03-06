# Author::    Liam Bennett  (mailto:lbennett@opentable.com)
# Copyright:: Copyright (c) 2013 OpenTable Inc
# License::   MIT

# == Class: kafka
#
# This class will install kafka binaries
#
# === Requirements/Dependencies
#
# Currently requires the puppetlabs/stdlib module on the Puppet Forge in
# order to validate much of the the provided configuration.
#
# === Parameters
#
# [*version*]
# The version of kafka that should be installed.
#
# [*scala_version*]
# The scala version what kafka was built with.
#
# [*install_dir*]
# The directory to install kafka to.
#
# [*mirror_url*]
# The url where the kafka is downloaded from.
#
# [*install_java*]
# Install java if it's not already installed.
#
# [*package_dir*]
# The directory to install kafka.
#
# [*manage_home*]
# Whether or not we should manage the kafka users
# home directory (create and remove with $ensure).
#
# === Examples
#
#
class kafka (
  $version       = $kafka::params::version,
  $scala_version = $kafka::params::scala_version,
  $install_dir   = '',
  $mirror_url    = $kafka::params::mirror_url,
  $install_java  = $kafka::params::install_java,
  $package_dir   = $kafka::params::package_dir,
  $manage_home   = $kafka::params::manage_home
) inherits kafka::params {

  validate_re($::osfamily, 'RedHat|Debian\b', "${::operatingsystem} not supported")
  #validate_re($version, '\d+\.\d+\.\d+\.*\d*', "${version} does not match semver")
  #validate_re($scala_version, '\d+\.\d+\.\d+\.*\d*', "${version} does not match semver")
  #validate_absolute_path($install_dir)
  validate_re($mirror_url, '^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$', "${mirror_url} is not a valid url")
  validate_bool($install_java, $manage_home)
  validate_absolute_path($package_dir)

  $basefilename      = "kafka_${scala_version}-${version}.tgz"
  $basename          = regsubst($basefilename, '(.+)\.tgz$', '\1')
  $package_url       = "${mirror_url}/kafka/${version}/${basefilename}"

  if $install_dir == '' {
    $install_directory = "/opt/kafka-${scala_version}-${version}"
  } else {
    $install_directory = $install_dir
  }

  if $install_java {
    class { 'java':
      distribution => 'jdk'
    }
  }

  if ! defined(Package['wget']) {
    package {'wget':
      ensure => present
    }
  }

  group { 'kafka':
    ensure => present
  } ->

  user { 'kafka':
    ensure      => present,
    shell       => '/bin/bash',
    home        => '/home/kafka',
    managehome  => $manage_home,
  } ->

  file {  '/home/kafka':
    ensure  => directory,
    owner   => 'kafka',
    group   => 'kafka',
    mode    => '0755',
  }

  file { $package_dir:
    ensure => 'directory',
    owner  => 'kafka',
    group  => 'kafka'
  }

  file { $install_directory:
    ensure => directory,
    owner  => 'kafka',
    group  => 'kafka',
    alias  => 'kafka-app-dir'
  }

  file { '/opt/kafka':
    ensure => link,
    target => $install_directory
  }

  file { '/opt/kafka/config':
    ensure  => directory,
    owner   => 'kafka',
    group   => 'kafka',
    require => File['/opt/kafka']
  }

  file { '/var/log/kafka':
    ensure => directory,
    owner  => 'kafka',
    group  => 'kafka'
  }

  exec { 'download-kafka-package':
    command => "wget -O ${package_dir}/${basefilename} ${package_url} 2> /dev/null",
    path    => ['/usr/bin', '/bin'],
    creates => "${package_dir}/${basefilename}",
    require => [ File[$package_dir], Package['wget'] ]
  }

  exec { 'untar-kafka-package':
    command => "tar xfvz ${package_dir}/${basefilename} -C ${install_directory} --strip-components=1",
    creates => "${install_directory}/LICENSE",
    alias   => 'untar-kafka',
    require => [ Exec['download-kafka-package'], File['kafka-app-dir'] ],
    user    => 'kafka',
    path    => ['/bin', '/usr/bin', '/usr/sbin']
  }

#    file_line {
#        'you are way too noisy sir please calm down 01':
#            path    => '/opt/kafka/config/log4j.properties',
#            line    => 'log4j.rootLogger=FATAL, stdout',
#            match   => '^log4j.rootLogger=INFO, stdout';
#        'you are way too noisy sir please calm down 02':
#            path    => '/opt/kafka/config/log4j.properties',
#            line    => 'log4j.logger.kafka=FATAL, kafkaAppender',
#            match   => '^log4j.logger.kafka=INFO, kafkaAppender';
#        'you are way too noisy sir please calm down 03':
#            path    => '/opt/kafka/config/log4j.properties',
#            line    => 'log4j.logger.kafka.log.LogCleaner=FATAL, cleanerAppender',
#            match   => '^log4j.logger.kafka.log.LogCleaner=INFO, cleanerAppender';
#    }
}
