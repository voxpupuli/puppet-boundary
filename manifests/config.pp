# This class is called from boundary::init to install the config file.
#
# @api private
class boundary::config {
  if $boundary::manage_service_file {
    systemd::unit_file { 'boundary.service':
      content => template('boundary/boundary.systemd.erb'),
    }
  }

  $_config = $boundary::pretty_config ? {
    true    => to_json_pretty($boundary::config_hash_real),
    default => to_json($boundary::config_hash_real),
  }

  $validate_cmd = $boundary::config_validator ? {
    'boundary_validator' => 'boundary config validate %',
    'ruby_validator' => '/usr/local/bin/config_validate.rb %',
    default => $boundary::config_validator,
  }

  file { '/usr/local/bin/config_validate.rb':
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    before => File['boundary config.json'],
    source => 'puppet:///modules/boundary/config_validate.rb',
  }
  file { $boundary::config_dir:
    ensure  => 'directory',
    owner   => $boundary::user,
    group   => $boundary::group,
    purge   => $boundary::purge_config_dir,
    recurse => $boundary::purge_config_dir,
  }
  -> file { 'boundary config.json':
    ensure       => file,
    owner        => $boundary::user,
    group        => $boundary::group,
    path         => "${boundary::config_dir}/config.json",
    mode         => $boundary::config_mode,
    validate_cmd => $validate_cmd,
    content      => $_config,
  }
  $content = join(map($boundary::env_vars) |$key, $value| { "${key}=${value}" }, "\n")
  file { "${boundary::config_dir}/boundary.env":
    ensure  => 'file',
    owner   => $boundary::user,
    group   => $boundary::group,
    mode    => $boundary::config_mode,
    content => "${content}\n",
    require => File[$boundary::config_dir],
  }
}
