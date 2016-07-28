require 'spec_helper'

RSpec.describe AtlassianJwtAuthentication::Helper do
  describe '#prepare_canonical_query_string' do
    subject { Object.new.extend(described_class) }

    before do
      described_class.send(:public, *described_class.protected_instance_methods)
      described_class.send(:public, *described_class.private_instance_methods)
    end

    it { is_expected.to respond_to(:prepare_canonical_query_string) }
  end
end