# Class: amazon_ssm_agent
# ===========================
#
# Download and install Amazon System Management Agent, amazon-ssm-agent.
#
# Parameters
# ----------
#
# * `ensure`
# Data Type: String
# Ensure state of the package. Can be 'present', 'latest', 'absent'
# Default value: 'latest'
#
# * `proxy_url`
# Data Type: String
# The proxy URL in <protocol>://<host>:<port> format, specify if the ssm agent needs to communicate via a proxy
# Default value: undef
#
# * `service_ensure`
# Data Type: String
# Ensure state of the service. Can be 'running', 'stopped'
# Default value: 'running'
#
# * `service_enable`
# Data Type: Boolean
# Whether to enable the service.
# Default value: true
#
# * `pkg_dir`
# Data Type: String
# Download location for the package.
# Default value: '/tmp'
#
#
# Examples
# --------
# @example
#    class { 'amazon_ssm_agent':
#      proxy_url => 'http://someproxy:3128',
#    }
#
# Authors
# -------
#
# Andy Wang <andy.wang@shinesolutions.com>
#
# Copyright
# ---------
#
# Copyright 2017-2019 Shine Solutions, unless otherwise noted.
#
class amazon_ssm_agent (
  String $ensure              = latest,
  Optional[String] $proxy_url = undef,
  Boolean $service_enable     = true,
  String $service_ensure      = 'running',
  String $pkg_dir             = '/tmp',
  ) {

    $pkg_provider = lookup('amazon_ssm_agent::pkg_provider', String, 'first')
    $pkg_format   = lookup('amazon_ssm_agent::pkg_format', String, 'first')
    $flavor       = lookup('amazon_ssm_agent::flavor', String, 'first')

    $srv_provider = lookup('amazon_ssm_agent::srv_provider', String, 'first')

    $pkg_local_path = "${pkg_dir}/amazon-ssm-agent.${pkg_format}"

    case $facts['os']['architecture'] {
      'x86_64','amd64': {
        $architecture = 'amd64'
      }
      'i386': {
        $architecture = '386'
      }
      'aarch64','arm64': {
        $architecture = 'arm64'
      }
      default: {
        fail("Module not supported on ${facts['os']['architecture']} architecture")
      }
    }

    $_archive_ensure = $ensure ? {
      absent  => absent,
      default => present,
    }

    $_archive_after_install_ensure = $ensure ? {
      latest  => absent,
      default => $ensure,
    }

    archive {$pkg_local_path:
      ensure  => $_archive_ensure,
      extract => false,
      cleanup => false,
      source  => "https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/${flavor}_${architecture}/amazon-ssm-agent.${pkg_format}",
    }
    -> package { 'amazon-ssm-agent':
      ensure   => $ensure,
      provider => $pkg_provider,
      source   => $pkg_local_path,
    }

    if $service_ensure {
      class { '::amazon_ssm_agent::proxy':
        proxy_url    => $proxy_url,
        srv_provider => $srv_provider,
        require      => Package['amazon-ssm-agent'],
      }

      service { 'amazon-ssm-agent':
        ensure   => $service_ensure,
        enable   => $service_enable,
        provider => $srv_provider,
      }

      Class['::amazon_ssm_agent::proxy'] -> Service['amazon-ssm-agent']
    }

    file {$pkg_local_path:
      ensure  => $_archive_after_install_ensure,
      require => Package['amazon-ssm-agent'],
    }
}
