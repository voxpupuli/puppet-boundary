# frozen_string_literal: true

require 'spec_helper'

describe 'boundary' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts.merge(service_provider: 'systemd', boundary_node_id: 'a1b2c3d4-1234-5678-9012-3456789abcde') }

      # Installation Stuff
      context 'On an unsupported arch' do
        let(:facts) { override_facts(super(), os: { architecture: 'bogus' }) }

        it { is_expected.to compile.and_raise_error(%r{Class\[Boundary\]: expects a value for parameter 'arch' }) }
      end

      context 'When not specifying whether to purge config' do
        it { is_expected.to contain_file('/etc/boundary.d').with(purge: true, recurse: true) }
      end

      context 'with all defaults' do
        it { is_expected.to compile.with_all_deps }
      end

      context 'When disable config purging' do
        let(:params) do
          {
            purge_config_dir: false
          }
        end

        it { is_expected.to contain_file('/etc/boundary.d').with(purge: false, recurse: false) }
      end

      context 'boundary::config should notify boundary::run_service' do
        let(:params) do
          {
            install_method: 'url',
            manage_service_file: true,
            version: '1.0.3'
          }
        end

        it { is_expected.to contain_class('boundary::config').that_notifies(['Class[boundary::run_service]']) }
        it { is_expected.to contain_systemd__unit_file('boundary.service').that_notifies(['Class[boundary::run_service]']) }
        it { is_expected.to contain_file('/usr/bin/boundary').that_notifies(['Class[boundary::run_service]']) }
      end

      context 'boundary::config should not notify boundary::run_service on config change' do
        let(:params) do
          {
            restart_on_change: false
          }
        end

        it { is_expected.not_to contain_class('boundary::config').that_notifies(['Class[boundary::run_service]']) }
      end

      context 'When joining boundary to a wan cluster by a known URL' do
        let(:params) do
          {
            join_wan: 'wan_host.test.com'
          }
        end

        it { is_expected.to contain_exec('join boundary wan').with(command: 'boundary join -wan wan_host.test.com') }
      end

      context 'By default, should not attempt to join a wan cluster' do
        it { is_expected.not_to contain_exec('join boundary wan') }
      end

      context 'When asked not to manage the repo' do
        let(:params) do
          {
            manage_repo: false
          }
        end

        it { is_expected.to compile.with_all_deps }

        case os_facts[:os]['family']
        when 'Debian'
          it { is_expected.not_to contain_apt__source('HashiCorp') }
        when 'RedHat'
          it { is_expected.not_to contain_yumrepo('HashiCorp') }
        end
      end

      context 'When asked to manage the repo but not to install using package' do
        let(:params) do
          {
            install_method: 'url',
            manage_service_file: true,
            version: '1.0.3',
            manage_repo: true
          }
        end

        it { is_expected.to compile.with_all_deps }

        case os_facts[:os]['family']
        when 'Debian'
          it { is_expected.not_to contain_apt__source('HashiCorp') }
        when 'RedHat'
          it { is_expected.not_to contain_yumrepo('HashiCorp') }
        end
      end

      context 'When asked to manage the repo and to install as package' do
        let(:params) do
          {
            install_method: 'package',
            manage_repo: true
          }
        end

        it { is_expected.to compile.with_all_deps }

        case os_facts[:os]['family']
        when 'Debian'
          it { is_expected.to contain_apt__source('HashiCorp') }
        when 'RedHat'
          it { is_expected.to contain_yumrepo('HashiCorp') }
        end
      end

      context 'When requesting to install via a package with defaults' do
        let(:params) do
          {
            install_method: 'package'
          }
        end

        it { is_expected.to contain_package('boundary').with(ensure: 'installed') }
      end

      context 'When requesting to install via a custom package and version' do
        let(:params) do
          {
            install_method: 'package',
            package_name: 'custom_boundary_package',
            version: 'specific_release'
          }
        end

        it { is_expected.to contain_package('custom_boundary_package').with(ensure: 'specific_release') }
      end

      context 'When installing via URL by default' do
        let(:params) do
          {
            install_method: 'url',
            version: '1.0.3'
          }
        end

        it { is_expected.to contain_archive('/opt/puppet-archive/boundary-1.0.3.zip').with(source: 'https://releases.hashicorp.com/boundary/1.0.3/boundary_1.0.3_linux_amd64.zip') }
        it { is_expected.to contain_file('/opt/puppet-archive').with(ensure: 'directory') }
        it { is_expected.to contain_file('/opt/puppet-archive/boundary-1.0.3').with(ensure: 'directory') }
        it { is_expected.to contain_file('/usr/bin/boundary').that_notifies(['Class[boundary::run_service]']) }
      end

      context 'When installing via URL by with a special version' do
        let(:params) do
          {
            install_method: 'url',
            version: '42',
          }
        end

        it { is_expected.to contain_archive('/opt/puppet-archive/boundary-42.zip').with(source: 'https://releases.hashicorp.com/boundary/42/boundary_42_linux_amd64.zip') }
        it { is_expected.to contain_file('/usr/bin/boundary').that_notifies(['Class[boundary::run_service]']) }
      end

      context 'When installing via URL by with a custom url' do
        let(:params) do
          {
            install_method: 'url',
            download_url: 'http://myurl',
            version: '1.0.3',
          }
        end

        it { is_expected.to contain_archive('/opt/puppet-archive/boundary-1.0.3.zip').with(source: 'http://myurl') }
        it { is_expected.to contain_file('/usr/bin/boundary').that_notifies(['Class[boundary::run_service]']) }
      end

      context 'When requesting to not to install' do
        let(:params) do
          {
            install_method: 'none'
          }
        end

        it { is_expected.not_to contain_package('boundary') }
        it { is_expected.not_to contain_archive('/opt/puppet-archive/boundary-1.0.3.zip') }
      end

      context 'When data_dir is provided' do
        let(:params) do
          {
            config_hash: {
              'data_dir' => '/dir1',
            },
          }
        end

        it { is_expected.to contain_file('/dir1').with(ensure: :directory, mode: '0755') }

        context 'When data_dir_mode is provided' do
          let(:params) do
            {
              config_hash: {
                'data_dir' => '/dir1',
              },
              data_dir_mode: '0750'
            }
          end

          it { is_expected.to contain_file('/dir1').with(mode: '0750') }
        end
      end

      context 'When data_dir not provided' do
        it { is_expected.not_to contain_file('/dir1').with(ensure: :directory) }
      end

      context 'The bootstrap_expect in config_hash is an int' do
        let(:params) do
          {
            config_hash: { 'bootstrap_expect' => 5 }
          }
        end

        it { is_expected.to contain_file('boundary config.json').with_content(%r{"bootstrap_expect":5}) }
        it { is_expected.not_to contain_file('boundary config.json').with_content(%r{"bootstrap_expect":"5"}) }
      end

      context 'Config_defaults is used to provide additional config' do
        let(:params) do
          {
            config_defaults: {
              'data_dir' => '/dir1',
            },
            config_hash: {
              'bootstrap_expect' => 5,
            }
          }
        end

        it { is_expected.to contain_file('boundary config.json').with_content(%r{"bootstrap_expect":5}) }
        it { is_expected.to contain_file('boundary config.json').with_content(%r{"data_dir":"/dir1"}) }
      end

      context 'Config_defaults is used to provide additional config and is overridden' do
        let(:params) do
          {
            config_defaults: {
              'data_dir' => '/dir1',
              'server' => false,
              'ports' => {
                'http' => 1,
                'rpc' => 8300,
              },
            },
            config_hash: {
              'bootstrap_expect' => 5,
              'server' => true,
              'ports' => {
                'http' => -1,
                'https' => 8500,
              },
            }
          }
        end

        it { is_expected.to contain_file('boundary config.json').with_content(%r{"bootstrap_expect":5}) }
        it { is_expected.to contain_file('boundary config.json').with_content(%r{"data_dir":"/dir1"}) }
        it { is_expected.to contain_file('boundary config.json').with_content(%r{"server":true}) }
        it { is_expected.to contain_file('boundary config.json').with_content(%r{"http":-1}) }
        it { is_expected.to contain_file('boundary config.json').with_content(%r{"https":8500}) }
        it { is_expected.to contain_file('boundary config.json').with_content(%r{"rpc":8300}) }
      end

      context 'When pretty config is true' do
        let(:params) do
          {
            pretty_config: true,
            config_hash: {
              'bootstrap_expect' => 5,
              'server' => true,
              'ports' => {
                'http' => -1,
                'https' => 8500,
              },
            }
          }
        end

        it { is_expected.to contain_file('boundary config.json').with_content(%r{"bootstrap_expect": 5,}) }
        it { is_expected.to contain_file('boundary config.json').with_content(%r{"server": true}) }
        it { is_expected.to contain_file('boundary config.json').with_content(%r{"http": -1,}) }
        it { is_expected.to contain_file('boundary config.json').with_content(%r{"https": 8500}) }
      end

      context 'When asked not to manage the service' do
        let(:params) { { manage_service: false } }

        it { is_expected.not_to contain_service('boundary') }
      end

      context 'When a reload_service is triggered with service_ensure stopped' do
        let :params do
          {
            service_ensure: 'stopped',
          }
        end

        it { is_expected.not_to contain_exec('reload boundary service') }
      end

      context 'When a reload_service is triggered with manage_service false' do
        let :params do
          {
            manage_service: false,
          }
        end

        it { is_expected.not_to contain_exec('reload boundary service') }
      end

      context 'Config with custom file mode' do
        let :params do
          {
            config_mode: '0600',
          }
        end

        it {
          expect(subject).to contain_file('boundary config.json').with(
            mode: '0600'
          )
        }
      end

      context 'When boundary is reloaded' do
        it {
          expect(subject).to contain_exec('reload boundary service').
            with_command('systemctl reload boundary')
        }
      end

      context 'When boundary is reloaded on a custom port' do
        let :params do
          {
            config_hash: {
              'ports' => {
                'rpc' => '9999'
              },
              'addresses' => {
                'rpc' => 'boundary.example.com'
              }
            }
          }
        end

        it {
          expect(subject).to contain_exec('reload boundary service').
            with_command('systemctl reload boundary')
        }
      end

      context 'When boundary is reloaded with a default client_addr' do
        let :params do
          {
            config_hash: {
              'client_addr' => '192.168.34.56',
            }
          }
        end

        it {
          expect(subject).to contain_exec('reload boundary service').
            with_command('systemctl reload boundary')
        }
      end

      # Config Stuff
      context 'With extra_options' do
        let(:params) do
          {
            manage_service_file: true,
            extra_options: '-some-extra-argument'
          }
        end

        it { is_expected.to contain_file('/etc/systemd/system/boundary.service').with_content(%r{^ExecStart=.*-some-extra-argument$}) }
      end

      context 'without env_vars' do
        it { is_expected.to contain_file('/etc/boundary.d/boundary.env').with_content("\n") }
      end

      context 'with env_vars' do
        let :params do
          {
            env_vars: {
              'TEST' => 'foobar',
              'BLA' => 'blub',
            }
          }
        end

        it { is_expected.to contain_file('/etc/boundary.d/boundary.env').with_content(%r{TEST=foobar}) }
        it { is_expected.to contain_file('/etc/boundary.d/boundary.env').with_content(%r{BLA=blub}) }
      end

      context 'With non-default user and group' do
        context 'with defaults' do
          let :params do
            {
              user: 'boundary',
              group: 'boundary',
            }
          end

          it { is_expected.to contain_file('/etc/boundary.d').with(owner: 'boundary', group: 'boundary') }
          it { is_expected.to contain_file('boundary config.json').with(owner: 'boundary', group: 'boundary') }
        end

        context 'with provided data_dir' do
          let :params do
            {
              config_hash: {
                'data_dir' => '/dir1',
              },
              user: 'boundary',
              group: 'boundary',
            }
          end

          it { is_expected.to contain_file('/dir1').with(ensure: 'directory', owner: 'boundary', group: 'boundary') }
        end

        context 'with env_vars' do
          let :params do
            {
              env_vars: {
                'TEST' => 'foobar',
                'BLA' => 'blub',
              },
              user: 'boundary',
              group: 'boundary',
            }
          end

          it { is_expected.to contain_file('/etc/boundary.d/boundary.env').with(content: %r{TEST=foobar}, owner: 'boundary', group: 'boundary') }
          it { is_expected.to contain_file('/etc/boundary.d/boundary.env').with(content: %r{BLA=blub}, owner: 'boundary', group: 'boundary') }
        end

        context 'with manage_service_file = true' do
          let :params do
            {
              user: 'boundary',
              group: 'boundary',
              manage_service_file: true,
            }
          end

          it { is_expected.to contain_file('/etc/systemd/system/boundary.service').with_content(%r{^User=boundary$}) }
          it { is_expected.to contain_file('/etc/systemd/system/boundary.service').with_content(%r{^Group=boundary$}) }
        end
      end

      context 'When host_volume is supplied' do
        let(:params) do
          {
            config_hash: {
              'client' => {
                'enabled' => true,
                'host_volume' => [
                  {
                    'test_application' => {
                      'path' => '/data/dir1',
                    },
                  }
                ],
              },
            }
          }
        end

        it { is_expected.to compile }
        it { is_expected.to contain_file('boundary config.json').with_content(%r{"path":"/data/dir1"}) }
        it { is_expected.to contain_file('/usr/local/bin/config_validate.rb').with(owner: 'root', group: 'root', mode: '0755', source: 'puppet:///modules/boundary/config_validate.rb', before: 'File[boundary config.json]') }
      end
    end
  end
end
