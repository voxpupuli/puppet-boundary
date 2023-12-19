# This class is meant to be called from certain
# configuration changes that support reload.
#
# @see https://developer.hashicorp.com/boundary/docs/configuration#configuration-reload
#
# @api private
class boundary::reload_service {
  # Don't attempt to reload if we're not supposed to be running.
  # This can happen during pre-provisioning of a node.
  if $boundary::manage_service == true and $boundary::service_ensure == 'running' {
    exec { 'reload boundary service':
      path        => ['/bin', '/usr/bin'],
      command     => 'systemctl reload boundary',
      refreshonly => true,
    }
  }
}
