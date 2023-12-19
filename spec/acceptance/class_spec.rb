# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'boundary class' do
  context 'default parameters' do
    it 'works with no errors based on the example' do
      pp = <<-EOS
        package { 'unzip': ensure => present }
        -> class { 'boundary':
          version        => '1.16.3',
          manage_service => true,
          config_hash    => {
              'datacenter' => 'east-aws',
              'data_dir'   => '/opt/boundary',
              'log_level'  => 'INFO',
              'node_name'  => 'foobar',
              'server'     => true,
          }
        }
      EOS

      # Run it twice and test for idempotency
      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_changes: true)
    end

    describe file('/opt/boundary') do
      it { is_expected.to be_directory }
    end

    describe service('boundary') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe command('boundary version') do
      its(:stdout) { is_expected.to match %r{Consul v1.16.3} }
    end

    describe file('/etc/boundary/config.json') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match(%r{server}) }
    end
  end

  context 'with performance options' do
    it 'works with no errors based on the example' do
      pp = <<-EOS
        package { 'unzip': ensure => present }
        -> class { 'boundary':
          version        => '1.16.3',
          manage_service => true,
          config_hash    => {
              'datacenter'  => 'east-aws',
              'data_dir'    => '/opt/boundary',
              'log_level'   => 'INFO',
              'node_name'   => 'foobar',
              'server'      => true,
              'performance' => {
                'raft_multiplier' => 2,
              },
          }
        }
      EOS

      # Run it twice and test for idempotency
      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_changes: true)
    end

    describe file('/opt/boundary') do
      it { is_expected.to be_directory }
    end

    describe service('boundary') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe command('boundary version') do
      its(:stdout) { is_expected.to match %r{Consul v1.16.3} }
    end

    describe file('/etc/boundary/config.json') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match(%r{server}) }
    end
  end

  context 'with new ACL system' do
    acl_master_token = '222bf65c-2477-4003-8f8e-842a4b394d8d'

    it 'works with no errors based on the example' do
      pp = <<-EOS
        package { 'unzip': ensure => present }
        -> class { 'boundary':
          version        => '1.16.3',
          manage_service => true,
          config_hash    => {
              'datacenter'         => 'east-aws',
              'primary_datacenter' => 'east-aws',
              'data_dir'           => '/opt/boundary',
              'log_level'          => 'INFO',
              'node_name'          => 'foobar',
              'server'             => true,
              'bootstrap'          => true,
              'bootstrap_expect'   => 1,
              'start_join'         => ['127.0.0.1'],
              'rejoin_after_leave' => true,
              'leave_on_terminate' => true,
              'client_addr'        => "0.0.0.0",
              'acl' => {
                'enabled'        => true,
                'default_policy' => 'allow',
                'down_policy'    => 'extend-cache',
                'tokens'         => {
                  'master' => '#{acl_master_token}'
                }
              },
          },
          acl_api_token    => '#{acl_master_token}',
          acl_api_hostname => '127.0.0.1',
          acl_api_tries    => 10,
          tokens => {
            'test_token_xyz' => {
              'accessor_id'      => '7c4e3f11-786d-44e6-ac1d-b99546a1ccbd',
              'policies_by_name' => ['test_policy_abc']
            },
            'test_token_absent' => {
              'accessor_id'      => '10381ad3-2837-43a6-b1ea-e27b7d53a749',
              'policies_by_name' => ['test_policy_abc'],
              'ensure'           => 'absent'
            }
          },
          policies => {
            'test_policy_abc' => {
              'description' => "This is a test policy",
              'rules'       => [
                {'resource' => 'service_prefix', 'segment' => 'tst_service', 'disposition' => 'read'},
                {'resource' => 'key', 'segment' => 'test_key', 'disposition' => 'write'},
                {'resource' => 'node_prefix', 'segment' => '', 'disposition' => 'deny'},
                {'resource' => 'operator', 'disposition' => 'read'},
              ],
            },
            'test_policy_absent' => {
              'description' => "This policy should not exists",
              'rules'       => [
                {'resource' => 'service_prefix', 'segment' => 'test_segment', 'disposition' => 'read'}
              ],
              'ensure'      => 'absent'
            }
          }
        }
      EOS

      # Run it twice to test for idempotency
      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_changes: true)
    end

    describe file('/opt/boundary') do
      it { is_expected.to be_directory }
    end

    describe service('boundary') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe command('boundary version') do
      its(:stdout) { is_expected.to match %r{Consul v1.16.3} }
    end

    describe command("boundary acl token list --token #{acl_master_token} | grep Description") do
      its(:stdout) { is_expected.to match %r{test_token_xyz} }
    end

    describe command("boundary acl token list --token #{acl_master_token} | grep -v Local | grep -v Create | grep -v Legacy | sed s/'.* - '//g") do
      its(:stdout) { is_expected.to include "test_token_xyz\nPolicies:\ntest_policy_abc" }
    end

    describe command("boundary acl policy read --name test_policy_abc --token #{acl_master_token}") do
      its(:stdout) do
        is_expected.to include "Rules:\nservice_prefix \"tst_service\" {\n  policy = \"read\"\n}\n\nkey \"test_key\" {\n  policy = \"write\"\n}\n\nnode_prefix \"\" {\n  policy = \"deny\"\n}"
      end
    end

    describe file('/etc/boundary/config.json') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match(%r{server}) }
    end
  end

  context 'cleanup' do
    it 'cleans up old mess' do
      pp = <<-EOS
        service { 'boundary':
          ensure => 'stopped',
          enable => false,
        }
        -> file { ['/opt/boundary', '/var/lib/boundary', '/etc/default/boundary', '/etc/sysconfig/boundary']:
          ensure => 'absent',
          force  => true,
        }
        -> file { '/etc/systemd/system/boundary.service':
          ensure => 'absent',
        }
        ~> exec { 'reload systemd':
          command     => 'systemctl daemon-reload',
          path        => $facts['path'],
          refreshonly => true,
        }
      EOS

      # Run it twice and test for idempotency
      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_changes: true)
    end

    describe file(['/opt/boundary', '/var/lib/boundary']) do
      it { is_expected.not_to be_directory }
    end
  end

  # no fedora packages available
  context 'package based installation', if: fact('os.name') != 'Fedora' do
    it 'runs boundary via package with explicit default data_dir' do
      pp = <<-EOS
      class { 'boundary':
        install_method  => 'package',
        manage_repo     => $facts['os']['name'] != 'Archlinux',
        init_style      => 'unmanaged',
        manage_data_dir => true,
        manage_group    => false,
        manage_user     => false,
        config_dir      => '/etc/boundary.d/',
        config_hash     => {
          'server'   => true,
        },
      }
      # default is Type=forking which has problems within CI
      # the module defaults to Type=exec, which makes sense
      systemd::dropin_file { 'type.conf':
        unit           => 'boundary.service',
        content        => "[Service]\nType=\nType=simple\n",
        notify_service => true,
      }
      systemd::dropin_file { 'foo.conf':
        unit           => 'boundary.service',
        content        => "[Unit]\nConditionFileNotEmpty=\nConditionFileNotEmpty=/etc/boundary.d/config.json\n",
        notify_service => true,
      }
      EOS

      # Run it twice and test for idempotency
      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_changes: true)
    end

    describe file('/etc/systemd/system/boundary.conf') do
      it { is_expected.not_to be_file }
    end

    describe file('/etc/systemd/system/boundary.service.d/foo.conf') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match(%r{ConditionFileNotEmpty=/etc/boundary.d/config.json}) }
    end

    describe file('/etc/boundary.d/config.json') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match(%r{server}) }
    end

    describe command('systemctl cat boundary') do
      its(:exit_status) { is_expected.to eq 0 }
      its(:stdout) { is_expected.to match(%r{Type=}) }
    end

    describe file('/opt/boundary') do
      it { is_expected.to be_directory }
    end

    describe service('boundary') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe package('boundary') do
      it { is_expected.to be_installed }
    end

    describe command('boundary version') do
      its(:stdout) { is_expected.to match %r{Consul v} }
    end
  end
end
