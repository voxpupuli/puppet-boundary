# This class is meant to be called from boundary
# It ensure the service is running
#
# @api private
class boundary::run_service {
  if $boundary::manage_service == true {
    service { 'boundary':
      ensure => $boundary::service_ensure,
      enable => $boundary::service_enable,
    }
  }

  if $boundary::join_wan {
    exec { 'join boundary wan':
      cwd       => $boundary::config_dir,
      path      => [$boundary::bin_dir,'/bin','/usr/bin'],
      command   => "boundary join -wan ${boundary::join_wan}",
      unless    => "boundary members -wan -detailed | grep -vP \"dc=${boundary::config_hash_real['datacenter']}\" | grep -P 'alive'",
      subscribe => Service['boundary'],
    }
  }
}
