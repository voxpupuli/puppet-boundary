# This class is called from boundary::init to install the config file.
#
# @api private
class boundary::install {
  if $boundary::data_dir {
    file { $boundary::data_dir:
      ensure => 'directory',
      owner  => $boundary::user,
      group  => $boundary::group,
      mode   => $boundary::data_dir_mode,
    }
  }

  case $boundary::install_method {
    'url': {
      $install_path = '/opt/puppet-archive'

      include 'archive'
      file { [$install_path, "${install_path}/boundary-${boundary::version}"]:
        ensure => directory,
      }
      -> archive { "${install_path}/boundary-${boundary::version}.${boundary::download_extension}":
        ensure       => present,
        source       => $boundary::real_download_url,
        extract      => true,
        extract_path => "${install_path}/boundary-${boundary::version}",
        creates      => "${install_path}/boundary-${boundary::version}/boundary",
      }
      -> file {
        "${install_path}/boundary-${boundary::version}/boundary":
          owner => 'root',
          group => 0, # 0 instead of root because OS X uses "wheel".
          mode  => '0555';
        "${boundary::bin_dir}/boundary":
          ensure => link,
          notify => $boundary::notify_service,
          target => "${install_path}/boundary-${boundary::version}/boundary";
      }
    }
    'package': {
      if $boundary::manage_repo {
        include hashi_stack::repo
        Class['hashi_stack::repo'] -> Package[$boundary::package_name]
      }
      package { $boundary::package_name:
        ensure => $boundary::version,
      }

      if $boundary::data_dir {
        Package[$boundary::package_name] -> File[$boundary::data_dir]
      }
    }
    'none': {}
    default: {
      fail("The provided install method ${boundary::install_method} is invalid")
    }
  }
}
