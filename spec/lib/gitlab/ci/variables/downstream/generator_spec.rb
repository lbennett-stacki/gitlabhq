# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Variables::Downstream::Generator, feature_category: :secrets_management do
  let(:bridge_variables) do
    Gitlab::Ci::Variables::Collection.fabricate(
      [
        { key: 'REF1', value: 'ref 1' },
        { key: 'REF2', value: 'ref 2' }
      ]
    )
  end

  let(:yaml_variables) do
    [
      { key: 'VAR1', value: 'variable 1' },
      { key: 'VAR2', value: 'variable 2' },
      { key: 'RAW_VAR3', value: '$REF1', raw: true },
      { key: 'INTERPOLATION_VAR4', value: 'interpolate $REF1 $REF2' }
    ]
  end

  let(:pipeline_variables) do
    [
      { key: 'PIPELINE_VAR1', value: 'variable 1' },
      { key: 'PIPELINE_VAR2', value: 'variable 2' },
      { key: 'PIPELINE_RAW_VAR3', value: '$REF1', raw: true },
      { key: 'PIPELINE_INTERPOLATION_VAR4', value: 'interpolate $REF1 $REF2' }
    ]
  end

  let(:pipeline_schedule_variables) do
    [
      { key: 'PIPELINE_SCHEDULE_VAR1', value: 'variable 1' },
      { key: 'PIPELINE_SCHEDULE_VAR2', value: 'variable 2' },
      { key: 'PIPELINE_SCHEDULE_RAW_VAR3', value: '$REF1', raw: true },
      { key: 'PIPELINE_SCHEDULE_INTERPOLATION_VAR4', value: 'interpolate $REF1 $REF2' }
    ]
  end

  let(:bridge) do
    instance_double(
      'Ci::Bridge',
      variables: bridge_variables,
      forward_yaml_variables?: true,
      forward_pipeline_variables?: true,
      yaml_variables: yaml_variables,
      pipeline_variables: pipeline_variables,
      pipeline_schedule_variables: pipeline_schedule_variables
    )
  end

  subject(:generator) { described_class.new(bridge) }

  describe '#calculate' do
    it 'creates attributes for downstream pipeline variables from the ' \
       'given yaml variables, pipeline variables and pipeline schedule variables' do
      expected = [
        { key: 'VAR1', value: 'variable 1' },
        { key: 'VAR2', value: 'variable 2' },
        { key: 'RAW_VAR3', value: '$REF1', raw: true },
        { key: 'INTERPOLATION_VAR4', value: 'interpolate ref 1 ref 2' },
        { key: 'PIPELINE_VAR1', value: 'variable 1' },
        { key: 'PIPELINE_VAR2', value: 'variable 2' },
        { key: 'PIPELINE_RAW_VAR3', value: '$REF1', raw: true },
        { key: 'PIPELINE_INTERPOLATION_VAR4', value: 'interpolate ref 1 ref 2' },
        { key: 'PIPELINE_SCHEDULE_VAR1', value: 'variable 1' },
        { key: 'PIPELINE_SCHEDULE_VAR2', value: 'variable 2' },
        { key: 'PIPELINE_SCHEDULE_RAW_VAR3', value: '$REF1', raw: true },
        { key: 'PIPELINE_SCHEDULE_INTERPOLATION_VAR4', value: 'interpolate ref 1 ref 2' }
      ]

      expect(generator.calculate).to contain_exactly(*expected)
    end

    it 'returns empty array when bridge has no variables' do
      allow(bridge).to receive(:yaml_variables).and_return([])
      allow(bridge).to receive(:pipeline_variables).and_return([])
      allow(bridge).to receive(:pipeline_schedule_variables).and_return([])

      expect(generator.calculate).to be_empty
    end
  end
end
