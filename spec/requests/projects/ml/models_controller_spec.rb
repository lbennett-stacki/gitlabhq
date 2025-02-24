# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Ml::ModelsController, feature_category: :mlops do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { project.first_owner }
  let_it_be(:model1_a) { create(:ml_model_package, project: project) }
  let_it_be(:model1_b) { create(:ml_model_package, project: project, name: model1_a.name) }
  let_it_be(:model2) { create(:ml_model_package, project: project) }

  let(:model_registry_enabled) { true }

  before do
    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?)
                        .with(user, :read_model_registry, project)
                        .and_return(model_registry_enabled)

    sign_in(user)
  end

  describe 'GET index' do
    subject(:index_request) do
      list_models
      response
    end

    it 'renders the template' do
      expect(index_request).to render_template('projects/ml/models/index')
    end

    it 'fetches the models using the finder' do
      expect(::Projects::Ml::ModelFinder).to receive(:new).with(project).and_call_original

      index_request
    end

    it 'prepares model view using the presenter' do
      expect(::Ml::ModelsIndexPresenter).to receive(:new).and_call_original

      index_request
    end

    it 'does not perform N+1 sql queries' do
      control_count = ActiveRecord::QueryRecorder.new(skip_cached: false) { list_models }

      create_list(:ml_model_package, 4, project: project)

      expect { list_models }.not_to exceed_all_query_limit(control_count)
    end

    context 'when user does not have access' do
      let(:model_registry_enabled) { false }

      it 'renders 404' do
        is_expected.to have_gitlab_http_status(:not_found)
      end
    end
  end

  private

  def list_models
    get project_ml_models_path(project)
  end
end
