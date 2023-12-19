# frozen_string_literal: true

require 'spec_helper'

describe Facter::Util::Fact do
  before do
    Facter.clear
  end

  describe 'boundary_version' do
    context 'Returns boundary version on Linux'
    it do
      boundary_version_output = <<~EOS
        {"revision":"a86ee182c2853913f019c2559f1451d926235707","version":"0.14.2","build_date":"2023-10-31T11:02:50Z"}
      EOS
      allow(Facter.fact(:kernel)).to receive(:value).and_return('Linux')
      allow(Facter::Util::Resolution).to receive(:exec).with('boundary version -format=json 2> /dev/null').
        and_return(boundary_version_output)
      expect(Facter.fact(:boundary_version).value).to match('0.14.2')
    end
  end
end
