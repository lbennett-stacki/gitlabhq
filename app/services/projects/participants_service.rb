# frozen_string_literal: true

module Projects
  class ParticipantsService < BaseService
    include Users::ParticipableService

    def execute(noteable)
      @noteable = noteable

      participants =
        noteable_owner +
        participants_in_noteable +
        all_members +
        groups +
        project_members

      render_participants_as_hash(participants.uniq)
    end

    def project_members
      @project_members ||= sorted(get_project_members)
    end

    def get_project_members
      members = Member.from_union([project_members_through_ancestral_groups,
                                   project_members_through_invited_groups,
                                   individual_project_members])

      User.id_in(members.select(:user_id))
    end

    def all_members
      return [] if Feature.enabled?(:disable_all_mention)

      [{ username: "all", name: "All Project and Group Members", count: project_members.count }]
    end

    private

    def project_members_through_invited_groups
      GroupMember
        .active_without_invites_and_requests
        .with_source_id(visible_groups.self_and_ancestors.pluck_primary_key)
        .select(*GroupMember.cached_column_list)
    end

    def visible_groups
      visible_groups = project.invited_groups

      unless project.team.member?(current_user)
        visible_groups = visible_groups.public_or_visible_to_user(current_user)
      end

      visible_groups
    end

    def project_members_through_ancestral_groups
      members = project.group.present? ? project.group.members_with_parents : Member.none
      members.select(*GroupMember.cached_column_list)
    end

    def individual_project_members
      project.project_members.select(*GroupMember.cached_column_list)
    end
  end
end
