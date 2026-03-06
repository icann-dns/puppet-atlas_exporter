# frozen_string_literal: true

require 'spec_helper'
require 'yaml'

base_config = {
    'measurements' => [
        { 'id' => 1, 'timeout' => '120s' },
        { 'id' => 2, 'timeout' => '5m' },
    ],
    'filter_invalid_results' => true,
    'histogram_buckets' => {},
}
histogram_config = base_config.merge(
    'histogram_buckets' => {
        'dns' => { 'rtt' => [25.0, 50.0, 100.0] },
    }
)
describe 'atlas_exporter' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:params) do
        {
            atlas_measurements: { 1 => '120s', 2 => '5m' },
        }
      end

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('atlas_exporter') }
        it { is_expected.to contain_package('prometheus-atlas-exporter').with_ensure('installed') }
        it { is_expected.to contain_file('/etc/prometheus-atlas-exporter') }
        it { is_expected.to contain_file('/etc/prometheus-atlas-exporter/config.yaml').with_content(YAML.dump(base_config)) }
      end
      context 'with histogram parameters' do
        let(:params) { super().merge(histogram_buckets: { 'dns' => [25.0, 50.0, 100.0] }) }
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_file('/etc/prometheus-atlas-exporter/config.yaml').with_content(YAML.dump(histogram_config)) }
      end
    end
  end
end
