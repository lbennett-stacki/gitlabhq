# frozen_string_literal: true

require "spec_helper"

RSpec.describe "User interacts with deploy keys", :js, feature_category: :groups_and_projects do
  let(:project) { create(:project, :repository) }
  let(:user) { project.first_owner }

  before do
    sign_in(user)
  end

  shared_examples "attaches a key" do
    it "attaches key" do
      visit(project_deploy_keys_path(project))

      page.within(".deploy-keys") do
        find(".badge", text: "1").click

        click_button("Enable")

        expect(page).not_to have_selector(".gl-spinner")
        expect(page).to have_current_path(project_settings_repository_path(project), ignore_query: true)

        find(".js-deployKeys-tab-enabled_keys").click

        expect(page).to have_content(deploy_key.title)
      end
    end
  end

  context "viewing deploy keys" do
    let(:deploy_key) { create(:deploy_key) }

    context "when project has keys" do
      before do
        create(:deploy_keys_project, project: project, deploy_key: deploy_key)
      end

      it "shows deploy keys" do
        visit(project_deploy_keys_path(project))

        page.within(".deploy-keys") do
          expect(page).to have_content(deploy_key.title)
        end
      end
    end

    context "when another project has keys" do
      let(:another_project) { create(:project) }

      before do
        create(:deploy_keys_project, project: another_project, deploy_key: deploy_key)

        another_project.add_maintainer(user)
      end

      it "shows deploy keys" do
        visit(project_deploy_keys_path(project))

        page.within(".deploy-keys") do
          find('.js-deployKeys-tab-available_project_keys').click

          expect(page).to have_content(deploy_key.title)
          expect(find(".js-deployKeys-tab-available_project_keys .badge")).to have_content("1")
        end
      end
    end

    context "when there are public deploy keys" do
      let!(:deploy_key) { create(:deploy_key, public: true) }

      it "shows public deploy keys" do
        visit(project_deploy_keys_path(project))

        page.within(".deploy-keys") do
          find(".js-deployKeys-tab-public_keys").click

          expect(page).to have_content(deploy_key.title)
        end
      end
    end
  end

  context "adding deploy keys" do
    before do
      visit(project_deploy_keys_path(project))
    end

    it "adds new key" do
      deploy_key_title = attributes_for(:key)[:title]
      deploy_key_body  = attributes_for(:key)[:key]

      fill_in("deploy_key_title", with: deploy_key_title)
      fill_in("deploy_key_key",   with: deploy_key_body)

      click_button("Add key")

      expect(page).to have_current_path(project_settings_repository_path(project), ignore_query: true)

      page.within(".deploy-keys") do
        expect(page).to have_content(deploy_key_title)
      end
    end
  end

  context "attaching existing keys" do
    context "from another project" do
      let(:another_project) { create(:project) }
      let(:deploy_key) { create(:deploy_key) }

      before do
        create(:deploy_keys_project, project: another_project, deploy_key: deploy_key)

        another_project.add_maintainer(user)
      end

      it_behaves_like "attaches a key"
    end

    context "when keys are public" do
      let!(:deploy_key) { create(:deploy_key, public: true) }

      it_behaves_like "attaches a key"
    end
  end
end
