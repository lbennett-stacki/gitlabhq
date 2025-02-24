# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Pipeline Editor', :js, feature_category: :pipeline_composition do
  include Features::SourceEditorSpecHelpers

  let(:project) { create(:project_empty_repo, :public) }
  let(:user) { create(:user) }

  let(:default_branch) { 'main' }
  let(:other_branch) { 'test' }
  let(:branch_with_invalid_ci) { 'despair' }

  let(:default_content) { 'Default' }

  let(:valid_content) do
    <<~YAML
    ---
    stages:
      - Build
      - Test
    job_a:
      script: echo hello
      stage: Build
    job_b:
      script: echo hello from job b
      stage: Test
    YAML
  end

  let(:invalid_content) do
    <<~YAML

      job3:
      stage: stage_foo
      script: echo 'Done.'
    YAML
  end

  before do
    sign_in(user)
    project.add_developer(user)

    project.repository.create_file(user, project.ci_config_path_or_default, default_content, message: 'Create CI file for main', branch_name: default_branch)
    project.repository.create_file(user, project.ci_config_path_or_default, valid_content, message: 'Create CI file for test', branch_name: other_branch)
    project.repository.create_file(user, project.ci_config_path_or_default, invalid_content, message: 'Create CI file for test', branch_name: branch_with_invalid_ci)

    visit project_ci_pipeline_editor_path(project)
    wait_for_requests
  end

  describe 'Default tabs' do
    it 'renders the edit tab as the default' do
      expect(page).to have_selector('[data-testid="editor-tab"]')
    end

    it 'renders the visualize, validate and full configuration tabs', :aggregate_failures do
      expect(page).to have_selector('[data-testid="visualization-tab"]', visible: :hidden)
      expect(page).to have_selector('[data-testid="validate-tab"]', visible: :hidden)
      expect(page).to have_selector('[data-testid="merged-tab"]', visible: :hidden)
    end
  end

  describe 'When CI yml has valid syntax' do
    before do
      visit project_ci_pipeline_editor_path(project, branch_name: other_branch)
      wait_for_requests
    end

    it 'shows "Pipeline syntax is correct" in the lint widget' do
      page.within('[data-testid="validation-segment"]') do
        expect(page).to have_content("Pipeline syntax is correct")
      end
    end

    it 'shows the graph in the visualization tab' do
      click_link "Visualize"

      page.within('[data-testid="graph-container"') do
        expect(page).to have_content("job_a")
      end
    end

    it 'can simulate pipeline in the validate tab' do
      click_link "Validate"

      click_button "Validate pipeline"
      wait_for_requests

      expect(page).to have_content("Simulation completed successfully")
    end

    it 'renders the merged yaml in the full configuration tab' do
      click_link "Full configuration"

      page.within('[data-testid="merged-tab"') do
        expect(page).to have_content("job_a")
      end
    end
  end

  describe 'When CI yml has invalid syntax' do
    before do
      visit project_ci_pipeline_editor_path(project, branch_name: branch_with_invalid_ci)
      wait_for_requests
    end

    it 'shows "Syntax is invalid" in the lint widget' do
      page.within('[data-testid="validation-segment"]') do
        expect(page).to have_content("This GitLab CI configuration is invalid")
      end
    end

    it 'does not render the graph in the visualization tab and shows error' do
      click_link "Visualize"

      expect(page).not_to have_selector('[data-testid="graph-container"')
      expect(page).to have_content("Your CI/CD configuration syntax is invalid. Select the Validate tab for more details.")
    end

    it 'gets a simulation error in the validate tab' do
      click_link "Validate"

      click_button "Validate pipeline"
      wait_for_requests

      expect(page).to have_content("Pipeline simulation completed with errors")
    end

    it 'renders merged yaml config' do
      click_link "Full configuration"

      page.within('[data-testid="merged-tab"') do
        expect(page).to have_content("job3")
      end
    end
  end

  describe 'with unparsable yaml' do
    it 'renders an error in the merged yaml tab' do
      click_link "Full configuration"

      page.within('[data-testid="merged-tab"') do
        expect(page).not_to have_content("job_a")
        expect(page).to have_content("Could not load full configuration content")
      end
    end
  end

  shared_examples 'default branch switcher behavior' do
    def switch_to_branch(branch)
      find('[data-testid="branch-selector"]').click

      page.within '[data-testid="branch-selector"]' do
        click_button branch
        wait_for_requests
      end
    end

    it 'displays current branch' do
      page.within('[data-testid="branch-selector"]') do
        expect(page).to have_content(default_branch)
        expect(page).not_to have_content(other_branch)
      end
    end

    it 'displays updated current branch after switching branches' do
      switch_to_branch(other_branch)

      page.within('[data-testid="branch-selector"]') do
        expect(page).to have_content(other_branch)
        expect(page).not_to have_content(default_branch)
      end
    end

    it 'displays new branch as selected after commiting on a new branch' do
      find('#source-branch-field').set('new_branch', clear: :backspace)

      page.within('#source-editor-') do
        find('textarea').send_keys '123'
      end

      click_button 'Commit changes'

      page.within('[data-testid="branch-selector"]') do
        expect(page).to have_content('new_branch')
        expect(page).not_to have_content(default_branch)
      end
    end
  end

  it 'user sees the Pipeline Editor page' do
    expect(page).to have_content('Pipeline Editor')
  end

  describe 'Branch Switcher' do
    before do
      visit project_ci_pipeline_editor_path(project)
      wait_for_requests

      # close button for the popover
      find('[data-testid="close-button"]').click
    end

    it_behaves_like 'default branch switcher behavior'
  end

  describe 'Editor navigation' do
    context 'when no change is made' do
      it 'user can navigate away without a browser alert' do
        expect(page).to have_content('Pipeline Editor')

        click_link 'Pipelines'

        expect(page).not_to have_content('Pipeline Editor')
      end
    end

    context 'when a change is made' do
      before do
        page.within('#source-editor-') do
          find('textarea').send_keys '123'
          # It takes some time after sending keys for the vue
          # component to update
          sleep 1
        end
      end

      it 'user who tries to navigate away can cancel the action and keep their changes', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/410496' do
        click_link 'Pipelines'

        page.driver.browser.switch_to.alert.dismiss

        expect(page).to have_content('Pipeline Editor')

        page.within('#source-editor-') do
          expect(page).to have_content("#{default_content}123")
        end
      end

      it 'user who tries to navigate away can confirm the action and discard their change', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/410496' do
        click_link 'Pipelines'

        page.driver.browser.switch_to.alert.accept

        expect(page).not_to have_content('Pipeline Editor')
      end

      it 'user who creates a MR is taken to the merge request page without warnings' do
        expect(page).not_to have_content('New merge request')

        find_field('Branch').set 'new_branch'
        find_field('Start a new merge request with these changes').click

        click_button 'Commit changes'

        expect(page).not_to have_content('Pipeline Editor')
        expect(page).to have_content('New merge request')
      end
    end
  end

  describe 'Commit Form' do
    it 'is preserved when changing tabs' do
      find('#commit-message').set('message', clear: :backspace)
      find('#source-branch-field').set('new_branch', clear: :backspace)

      click_link 'Validate'
      click_link 'Edit'

      expect(find('#commit-message').value).to eq('message')
      expect(find('#source-branch-field').value).to eq('new_branch')
    end
  end

  describe 'Editor content' do
    it 'user can reset their CI configuration' do
      page.within('#source-editor-') do
        find('textarea').send_keys '123'
      end

      # It takes some time after sending keys for the reset
      # btn to register the changes inside the editor
      sleep 1
      click_button 'Reset'

      expect(page).to have_css('#reset-content')

      page.within('#reset-content') do
        click_button 'Reset file'
      end

      page.within('#source-editor-') do
        expect(page).to have_content(default_content)
        expect(page).not_to have_content("#{default_content}123")
      end
    end

    it 'user can cancel reseting their CI configuration' do
      page.within('#source-editor-') do
        find('textarea').send_keys '123'
      end

      # It takes some time after sending keys for the reset
      # btn to register the changes inside the editor
      sleep 1
      click_button 'Reset'

      expect(page).to have_css('#reset-content')

      page.within('#reset-content') do
        click_button 'Cancel'
      end

      page.within('#source-editor-') do
        expect(page).to have_content("#{default_content}123")
      end
    end
  end
end
