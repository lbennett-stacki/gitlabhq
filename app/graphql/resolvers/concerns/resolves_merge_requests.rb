# frozen_string_literal: true

# Mixin for resolving merge requests. All arguments must be in forms
# that `MergeRequestsFinder` can handle, so you may need to use aliasing.
module ResolvesMergeRequests
  extend ActiveSupport::Concern
  include LooksAhead

  included do
    type Types::MergeRequestType, null: true
  end

  def resolve_with_lookahead(**args)
    if args[:group_id]
      args[:group_id] = ::GitlabSchema.parse_gid(args[:group_id], expected_type: ::Group).model_id
      args[:include_subgroups] = true
    end

    mr_finder = MergeRequestsFinder.new(current_user, args.compact)
    finder = Gitlab::Graphql::Loaders::IssuableLoader.new(mr_parent, mr_finder)

    select_result(finder.batching_find_all { |query| apply_lookahead(query) })
  end

  def ready?(**args)
    return early_return if no_results_possible?(args)

    super
  end

  def early_return
    [false, single? ? nil : MergeRequest.none]
  end

  private

  def mr_parent
    project
  end

  def unconditional_includes
    [:target_project, :author]
  end

  def preloads
    {
      assignees: [:assignees],
      award_emoji: { award_emoji: [:awardable] },
      reviewers: [:reviewers],
      participants: MergeRequest.participant_includes,
      author: [:author],
      merged_at: [:metrics],
      commit_count: [:metrics],
      diff_stats_summary: [:metrics],
      approved_by: [:approved_by_users],
      milestone: [:milestone],
      security_auto_fix: [:author],
      head_pipeline: [:merge_request_diff, { head_pipeline: [:merge_request] }],
      timelogs: [:timelogs],
      pipelines: [:merge_request_diffs], # used by `recent_diff_head_shas` to load pipelines
      committers: [merge_request_diff: [:merge_request_diff_commits]],
      suggested_reviewers: [:predictions]
    }
  end
end
