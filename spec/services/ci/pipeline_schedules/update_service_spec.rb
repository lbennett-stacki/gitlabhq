# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::PipelineSchedules::UpdateService, feature_category: :continuous_integration do
  let_it_be(:user) { create(:user) }
  let_it_be(:reporter) { create(:user) }
  let_it_be(:project) { create(:project, :public, :repository) }
  let_it_be(:pipeline_schedule) { create(:ci_pipeline_schedule, project: project, owner: user) }

  let_it_be(:pipeline_schedule_variable) do
    create(:ci_pipeline_schedule_variable,
      key: 'foo', value: 'foovalue', pipeline_schedule: pipeline_schedule)
  end

  before_all do
    project.add_maintainer(user)
    project.add_reporter(reporter)

    pipeline_schedule.reload
  end

  describe "execute" do
    context 'when user does not have permission' do
      subject(:service) { described_class.new(pipeline_schedule, reporter, {}) }

      it 'returns ServiceResponse.error' do
        result = service.execute

        expect(result).to be_a(ServiceResponse)
        expect(result.error?).to be(true)

        error_message = _('The current user is not authorized to update the pipeline schedule')
        expect(result.message).to match_array([error_message])
        expect(pipeline_schedule.errors).to match_array([error_message])
      end
    end

    context 'when user has permission' do
      let(:params) do
        {
          description: 'updated_desc',
          ref: 'patch-x',
          active: false,
          cron: '*/1 * * * *',
          variables_attributes: [
            { id: pipeline_schedule_variable.id, key: 'bar', secret_value: 'barvalue' }
          ]
        }
      end

      subject(:service) { described_class.new(pipeline_schedule, user, params) }

      it 'updates database values with passed params' do
        expect { service.execute }
          .to change { pipeline_schedule.description }.from('pipeline schedule').to('updated_desc')
          .and change { pipeline_schedule.ref }.from('master').to('patch-x')
          .and change { pipeline_schedule.active }.from(true).to(false)
          .and change { pipeline_schedule.cron }.from('0 1 * * *').to('*/1 * * * *')
          .and change { pipeline_schedule.variables.last.key }.from('foo').to('bar')
          .and change { pipeline_schedule.variables.last.value }.from('foovalue').to('barvalue')
      end

      context 'when creating a variable' do
        let(:params) do
          {
            variables_attributes: [
              { key: 'ABC', secret_value: 'ABC123' }
            ]
          }
        end

        it 'creates the new variable' do
          expect { service.execute }.to change { Ci::PipelineScheduleVariable.count }.by(1)

          expect(pipeline_schedule.variables.last.key).to eq('ABC')
          expect(pipeline_schedule.variables.last.value).to eq('ABC123')
        end
      end

      context 'when deleting a variable' do
        let(:params) do
          {
            variables_attributes: [
              {
                id: pipeline_schedule_variable.id,
                _destroy: true
              }
            ]
          }
        end

        it 'deletes the existing variable' do
          expect { service.execute }.to change { Ci::PipelineScheduleVariable.count }.by(-1)
        end
      end

      it 'returns ServiceResponse.success' do
        result = service.execute

        expect(result).to be_a(ServiceResponse)
        expect(result.success?).to be(true)
        expect(result.payload.description).to eq('updated_desc')
      end

      context 'when schedule update fails' do
        subject(:service) { described_class.new(pipeline_schedule, user, {}) }

        before do
          allow(pipeline_schedule).to receive(:save).and_return(false)

          errors = ActiveModel::Errors.new(pipeline_schedule)
          errors.add(:base, 'An error occurred')
          allow(pipeline_schedule).to receive(:errors).and_return(errors)
        end

        it 'returns ServiceResponse.error' do
          result = service.execute

          expect(result).to be_a(ServiceResponse)
          expect(result.error?).to be(true)
          expect(result.message).to match_array(['An error occurred'])
        end
      end
    end
  end
end
