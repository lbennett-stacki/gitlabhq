# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Nav::TopNavHelper do
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:admin) { build_stubbed(:user, :admin) }
  let_it_be(:external_user) { build_stubbed(:user, :external, can_create_group: false) }

  let(:current_user) { nil }

  before do
    stub_application_setting(snowplow_enabled: true)
    allow(helper).to receive(:current_user) { current_user }
  end

  describe '#top_nav_view_model' do
    let(:current_project) { nil }
    let(:current_group) { nil }
    let(:with_current_settings_admin_mode) { false }
    let(:with_header_link_admin_mode) { false }
    let(:with_projects) { false }
    let(:with_groups) { false }
    let(:with_milestones) { false }
    let(:with_snippets) { false }
    let(:with_activity) { false }

    let(:subject) { helper.top_nav_view_model(project: current_project, group: current_group) }

    let(:menu_tooltip) { 'Main menu' }

    before do
      allow(Gitlab::CurrentSettings).to receive(:admin_mode) { with_current_settings_admin_mode }
      allow(helper).to receive(:header_link?).with(:admin_mode) { with_header_link_admin_mode }

      # Defaulting all `dashboard_nav_link?` calls to false ensures the EE-specific behavior
      # is not enabled in this CE spec
      allow(helper).to receive(:dashboard_nav_link?).with(anything) { false }

      allow(helper).to receive(:dashboard_nav_link?).with(:projects) { with_projects }
      allow(helper).to receive(:dashboard_nav_link?).with(:groups) { with_groups }
      allow(helper).to receive(:dashboard_nav_link?).with(:milestones) { with_milestones }
      allow(helper).to receive(:dashboard_nav_link?).with(:snippets) { with_snippets }
      allow(helper).to receive(:dashboard_nav_link?).with(:activity) { with_activity }
    end

    it 'has :menuTooltip' do
      expect(subject[:menuTooltip]).to eq(menu_tooltip)
    end

    context 'when current_user is nil (anonymous)' do
      it 'has expected :primary' do
        expected_header = ::Gitlab::Nav::TopNavMenuHeader.build(
          title: 'Explore'
        )
        expected_primary = [
          { href: '/explore', icon: 'project', id: 'project', title: 'Projects' },
          { href: '/explore/groups', icon: 'group', id: 'groups', title: 'Groups' },
          { href: '/explore/projects/topics', icon: 'labels', id: 'topics', title: 'Topics' },
          { href: '/explore/snippets', icon: 'snippet', id: 'snippets', title: 'Snippets' }
        ].map do |item|
          ::Gitlab::Nav::TopNavMenuItem.build(**item)
        end

        expect(subject[:primary]).to eq([expected_header, *expected_primary])
      end

      it 'has expected :shortcuts' do
        expected_shortcuts = [
          {
            href: '/explore',
            id: 'project-shortcut',
            title: 'Projects',
            css_class: 'dashboard-shortcuts-projects'
          },
          {
            href: '/explore/groups',
            id: 'groups-shortcut',
            title: 'Groups',
            css_class: 'dashboard-shortcuts-groups'
          },
          {
            href: '/explore/projects/topics',
            id: 'topics-shortcut',
            title: 'Topics',
            css_class: 'dashboard-shortcuts-topics'
          },
          {
            href: '/explore/snippets',
            id: 'snippets-shortcut',
            title: 'Snippets',
            css_class: 'dashboard-shortcuts-snippets'
          }
        ].map do |item|
          ::Gitlab::Nav::TopNavMenuItem.build(**item)
        end

        expect(subject[:shortcuts]).to eq(expected_shortcuts)
      end

      context 'with current nav as project' do
        before do
          helper.nav('project')
        end

        it 'has expected :active' do
          expect(subject[:primary].detect { |entry| entry[:id] == 'project' }[:active]).to eq(true)
        end
      end
    end

    context 'when current_user is non-admin' do
      let(:current_user) { user }

      it 'has no menu items or views by default' do
        expect(subject).to eq({ menuTooltip: menu_tooltip,
                                primary: [],
                                secondary: [],
                                shortcuts: [],
                                views: {} })
      end

      context 'with projects' do
        let(:with_projects) { true }
        let(:projects_view) { subject[:views][:projects] }

        it 'has expected :primary' do
          expected_header = ::Gitlab::Nav::TopNavMenuHeader.build(
            title: 'Switch to'
          )
          expected_primary = ::Gitlab::Nav::TopNavMenuItem.build(
            data: {
              track_action: 'click_dropdown',
              track_label: 'projects_dropdown',
              track_property: 'navigation_top',
              testid: 'projects_dropdown'
            },
            icon: 'project',
            id: 'project',
            title: 'Projects',
            view: 'projects'
          )
          expect(subject[:primary]).to eq([expected_header, expected_primary])
        end

        it 'has expected :shortcuts' do
          expected_shortcuts = ::Gitlab::Nav::TopNavMenuItem.build(
            id: 'project-shortcut',
            title: 'Projects',
            href: '/dashboard/projects',
            css_class: 'dashboard-shortcuts-projects'
          )
          expect(subject[:shortcuts]).to eq([expected_shortcuts])
        end

        context 'projects' do
          it 'has expected :currentUserName' do
            expect(projects_view[:currentUserName]).to eq(current_user.username)
          end

          it 'has expected :namespace' do
            expect(projects_view[:namespace]).to eq('projects')
          end

          it 'has expected :linksPrimary' do
            expected_links_primary = [
              ::Gitlab::Nav::TopNavMenuItem.build(
                data: {
                  testid: 'menu_item_link',
                  qa_title: 'View all projects',
                  **menu_data_tracking_attrs('view_all_projects')
                },
                href: '/dashboard/projects',
                id: 'your',
                title: 'View all projects'
              )
            ]
            expect(projects_view[:linksPrimary]).to eq(expected_links_primary)
          end

          it 'does not have any :linksSecondary' do
            expect(projects_view[:linksSecondary]).to eq([])
          end

          context 'with current nav as project' do
            before do
              helper.nav('project')
            end

            it 'has expected :active' do
              expect(subject[:primary].detect { |entry| entry[:id] == 'project' }[:active]).to eq(true)
            end
          end

          context 'with persisted project' do
            let_it_be(:project) { build_stubbed(:project) }

            let(:current_project) { project }
            let(:avatar_url) { 'project_avatar_url' }

            before do
              allow(project).to receive(:persisted?) { true }
              allow(project).to receive(:avatar_url) { avatar_url }
            end

            it 'has project as :container' do
              expected_container = {
                avatarUrl: avatar_url,
                id: project.id,
                name: project.name,
                namespace: project.full_name,
                webUrl: project_path(project)
              }

              expect(projects_view[:currentItem]).to eq(expected_container)
            end
          end
        end
      end

      context 'with groups' do
        let(:with_groups) { true }
        let(:groups_view) { subject[:views][:groups] }

        it 'has expected :primary' do
          expected_header = ::Gitlab::Nav::TopNavMenuHeader.build(
            title: 'Switch to'
          )
          expected_primary = ::Gitlab::Nav::TopNavMenuItem.build(
            data: {
              track_action: 'click_dropdown',
              track_label: 'groups_dropdown',
              track_property: 'navigation_top',
              testid: 'groups_dropdown'
            },
            icon: 'group',
            id: 'groups',
            title: 'Groups',
            view: 'groups'
          )
          expect(subject[:primary]).to eq([expected_header, expected_primary])
        end

        it 'has expected :shortcuts' do
          expected_shortcuts = ::Gitlab::Nav::TopNavMenuItem.build(
            id: 'groups-shortcut',
            title: 'Groups',
            href: '/dashboard/groups',
            css_class: 'dashboard-shortcuts-groups'
          )
          expect(subject[:shortcuts]).to eq([expected_shortcuts])
        end

        context 'groups' do
          it 'has expected :currentUserName' do
            expect(groups_view[:currentUserName]).to eq(current_user.username)
          end

          it 'has expected :namespace' do
            expect(groups_view[:namespace]).to eq('groups')
          end

          it 'has expected :linksPrimary' do
            expected_links_primary = [
              ::Gitlab::Nav::TopNavMenuItem.build(
                data: {
                  testid: 'menu_item_link',
                  qa_title: 'View all groups',
                  **menu_data_tracking_attrs('view_all_groups')
                },
                href: '/dashboard/groups',
                id: 'your',
                title: 'View all groups'
              )
            ]
            expect(groups_view[:linksPrimary]).to eq(expected_links_primary)
          end

          it 'does not have any :linksSecondary' do
            expect(groups_view[:linksSecondary]).to eq([])
          end

          context 'with external user' do
            let(:current_user) { external_user }

            it 'does not have create group link' do
              expect(groups_view[:linksSecondary]).to eq([])
            end
          end

          context 'with current nav as group' do
            before do
              helper.nav('group')
            end

            it 'has expected :active' do
              expect(subject[:primary].detect { |entry| entry[:id] == 'groups' }[:active]).to eq(true)
            end
          end

          context 'with persisted group' do
            let_it_be(:group) { build_stubbed(:group) }

            let(:current_group) { group }
            let(:avatar_url) { 'group_avatar_url' }

            before do
              allow(group).to receive(:persisted?) { true }
              allow(group).to receive(:avatar_url) { avatar_url }
            end

            it 'has expected :container' do
              expected_container = {
                avatarUrl: avatar_url,
                id: group.id,
                name: group.name,
                namespace: group.full_name,
                webUrl: group_path(group)
              }

              expect(groups_view[:currentItem]).to eq(expected_container)
            end
          end
        end
      end

      context 'with milestones' do
        let(:with_milestones) { true }

        it 'has expected :shortcuts' do
          expected_shortcuts = ::Gitlab::Nav::TopNavMenuItem.build(
            id: 'milestones-shortcut',
            title: 'Milestones',
            href: '/dashboard/milestones',
            css_class: 'dashboard-shortcuts-milestones'
          )
          expect(subject[:shortcuts]).to eq([expected_shortcuts])
        end
      end

      context 'with snippets' do
        let(:with_snippets) { true }

        it 'has expected :shortcuts' do
          expected_shortcuts = ::Gitlab::Nav::TopNavMenuItem.build(
            id: 'snippets-shortcut',
            title: 'Snippets',
            href: '/dashboard/snippets',
            css_class: 'dashboard-shortcuts-snippets'
          )
          expect(subject[:shortcuts]).to eq([expected_shortcuts])
        end
      end

      context 'with activity' do
        let(:with_activity) { true }

        it 'has expected :shortcuts' do
          expected_shortcuts = ::Gitlab::Nav::TopNavMenuItem.build(
            id: 'activity-shortcut',
            title: 'Activity',
            href: '/dashboard/activity',
            css_class: 'dashboard-shortcuts-activity'
          )
          expect(subject[:shortcuts]).to eq([expected_shortcuts])
        end
      end
    end

    context 'when current_user is admin' do
      let_it_be(:current_user) { admin }

      let(:with_current_settings_admin_mode) { true }

      it 'has admin as first :secondary item' do
        expected_admin_item = ::Gitlab::Nav::TopNavMenuItem.build(
          data: {
            testid: 'admin_area_link',
            **menu_data_tracking_attrs('admin')
          },
          id: 'admin',
          title: 'Admin',
          icon: 'admin',
          href: '/admin'
        )

        expect(subject[:secondary].first).to eq(expected_admin_item)
      end

      context 'with header link admin_mode true' do
        let(:with_header_link_admin_mode) { true }

        it 'has leave_admin_mode as last :secondary item' do
          expected_leave_admin_mode_item = ::Gitlab::Nav::TopNavMenuItem.build(
            id: 'leave_admin_mode',
            title: 'Leave admin mode',
            icon: 'lock-open',
            href: '/admin/session/destroy',
            data: { method: 'post', **menu_data_tracking_attrs('leave_admin_mode') }
          )
          expect(subject[:secondary].last).to eq(expected_leave_admin_mode_item)
        end
      end

      context 'with header link admin_mode false' do
        let(:with_header_link_admin_mode) { false }

        it 'has enter_admin_mode as last :secondary item' do
          expected_enter_admin_mode_item = ::Gitlab::Nav::TopNavMenuItem.build(
            data: {
              testid: 'menu_item_link',
              qa_title: 'Enter admin mode',
              **menu_data_tracking_attrs('enter_admin_mode')
            },
            id: 'enter_admin_mode',
            title: 'Enter admin mode',
            icon: 'lock',
            href: '/admin/session/new'
          )
          expect(subject[:secondary].last).to eq(expected_enter_admin_mode_item)
        end
      end
    end
  end

  describe '#top_nav_responsive_view_model' do
    let_it_be(:project) { create(:project) }
    let_it_be(:group) { create(:group) }

    let(:with_search) { false }
    let(:with_new_view_model) { nil }

    let(:subject) { helper.top_nav_responsive_view_model(project: project, group: group) }

    before do
      allow(helper).to receive(:header_link?).with(:search) { with_search }
      allow(helper).to receive(:new_dropdown_view_model).with(project: project, group: group) { with_new_view_model }
    end

    it 'has nil new subview' do
      expect(subject[:views][:new]).to be_nil
    end

    it 'has nil search subview' do
      expect(subject[:views][:search]).to be_nil
    end

    context 'with search' do
      let(:with_search) { true }

      it 'has search subview' do
        expect(subject[:views][:search]).to eq(
          ::Gitlab::Nav::TopNavMenuItem.build(
            id: 'search',
            title: 'Search',
            icon: 'search',
            href: search_path
          )
        )
      end
    end

    context 'with new' do
      let(:with_new_view_model) { { menu_sections: [{ id: 'test-new-view-model' }] } }

      it 'has new subview' do
        expect(subject[:views][:new]).to eq(with_new_view_model)
      end
    end

    context 'with new and no menu_sections' do
      let(:with_new_view_model) { { menu_sections: [] } }

      it 'has new subview' do
        expect(subject[:views][:new]).to be_nil
      end
    end
  end

  def menu_data_tracking_attrs(label)
    {
      track_label: "menu_#{label}",
      track_action: 'click_dropdown',
      track_property: 'navigation_top'
    }
  end
end
