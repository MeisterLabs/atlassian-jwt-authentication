require 'spec_helper'

RSpec.describe AtlassianJwtAuthentication::HTTParty do
  describe '#prepare_canonical_query_string' do
    subject {
      klass = Class.new
      klass.instance_eval { include AtlassianJwtAuthentication::HTTParty }
      klass
    }

    before do
      described_class.send(:public, *described_class.protected_instance_methods)
      described_class.send(:public, *described_class.private_instance_methods)
    end

    it 'exists' do
      is_expected.to respond_to(:prepare_canonical_query_string)
    end

    it 'sorts parameters' do
      expect(subject.prepare_canonical_query_string(query: {test: %w(c b), another: 'old'})).to eq 'another=old&test=b,c'
    end

    it 'returns empty string for empty params' do
      expect(subject.prepare_canonical_query_string(query: {})).to eq ''
    end

    it 'processes body and query' do
      expect(subject.prepare_canonical_query_string(query: {query: 'yes'},
        body: {test: %w(c b), another: 'old'})).to eq 'another=old&query=yes&test=b,c'
    end

    it 'ignores body that\'s not a hash' do
      expect(subject.prepare_canonical_query_string(body: {test: %w(c b), another: 'old'}.to_json)).to eq ''
    end

  end
end