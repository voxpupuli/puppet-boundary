# frozen_string_literal: true
require 'json'

# boundary_version.rb
#
Facter.add(:boundary_version) do
  confine kernel: 'Linux'
  boundary_version = JSON.parse(Facter::Util::Resolution.exec('boundary version -format=json 2> /dev/null'))
  setcode do
    boundary_version["version"]
  rescue StandardError
    nil
  end
end
