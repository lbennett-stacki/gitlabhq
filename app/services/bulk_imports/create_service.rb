# frozen_string_literal: true

# Entry point of the BulkImport/Direct Transfer feature.
# This service receives a Gitlab Instance connection params
# and a list of groups or projects to be imported.
#
# Process topography:
#
#       sync      |   async
#                 |
#  User +--> P1 +----> Pn +---+
#                 |     ^     | Enqueue new job
#                 |     +-----+
#
# P1 (sync)
#
# - Create a BulkImport record
# - Create a BulkImport::Entity for each group or project (entities) to be imported
# - Enqueue a BulkImportWorker job (P2) to import the given entity
#
# Pn (async)
#
# - For each group to be imported (BulkImport::Entity.with_status(:created))
#   - Import the group data
#   - Create entities for each subgroup of the imported group
#   - Create entities for each project of the imported group
#   - Enqueue a BulkImportWorker job (Pn) to import the new entities

module BulkImports
  class CreateService
    ENTITY_TYPES_MAPPING = {
      'group_entity' => 'groups',
      'project_entity' => 'projects'
    }.freeze

    attr_reader :current_user, :params, :credentials

    def initialize(current_user, params, credentials)
      @current_user = current_user
      @params = params
      @credentials = credentials
    end

    def execute
      validate!

      bulk_import = create_bulk_import

      Gitlab::Tracking.event(
        self.class.name,
        'create',
        label: 'bulk_import_group',
        extra: { source_equals_destination: source_equals_destination? }
      )

      BulkImportWorker.perform_async(bulk_import.id)

      ServiceResponse.success(payload: bulk_import)

    rescue ActiveRecord::RecordInvalid, BulkImports::Error, BulkImports::NetworkError => e
      ServiceResponse.error(
        message: e.message,
        http_status: :unprocessable_entity
      )
    end

    private

    def validate!
      client.validate_instance_version!
      validate_setting_enabled!
      client.validate_import_scopes!
    end

    def create_bulk_import
      BulkImport.transaction do
        bulk_import = BulkImport.create!(
          user: current_user,
          source_type: 'gitlab',
          source_version: client.instance_version,
          source_enterprise: client.instance_enterprise
        )
        bulk_import.create_configuration!(credentials.slice(:url, :access_token))

        Array.wrap(params).each do |entity_params|
          track_access_level(entity_params)

          validate_destination_namespace(entity_params)
          validate_destination_slug(entity_params[:destination_slug] || entity_params[:destination_name])
          validate_destination_full_path(entity_params)

          BulkImports::Entity.create!(
            bulk_import: bulk_import,
            source_type: entity_params[:source_type],
            source_full_path: entity_params[:source_full_path],
            destination_slug: entity_params[:destination_slug] || entity_params[:destination_name],
            destination_namespace: entity_params[:destination_namespace],
            migrate_projects: Gitlab::Utils.to_boolean(entity_params[:migrate_projects], default: true)
          )
        end
        bulk_import
      end
    end

    def validate_setting_enabled!
      source_full_path, source_type = Array.wrap(params)[0].values_at(:source_full_path, :source_type)
      entity_type = ENTITY_TYPES_MAPPING.fetch(source_type)
      if source_full_path =~ /^[0-9]+$/
        query = query_type(entity_type)
        response = graphql_client.execute(
          graphql_client.parse(query.to_s),
          { full_path: source_full_path }
        ).original_hash

        source_entity_identifier = ::GlobalID.parse(response.dig(*query.data_path, 'id')).model_id
      else
        source_entity_identifier = ERB::Util.url_encode(source_full_path)
      end

      client.get("/#{entity_type}/#{source_entity_identifier}/export_relations/status")
    rescue BulkImports::NetworkError => e
      # the source instance will return a 404 if the feature is disabled as the endpoint won't be available
      return if e.cause.is_a?(Gitlab::HTTP::BlockedUrlError)

      raise ::BulkImports::Error.setting_not_enabled
    end

    def track_access_level(entity_params)
      Gitlab::Tracking.event(
        self.class.name,
        'create',
        label: 'import_access_level',
        user: current_user,
        extra: { user_role: user_role(entity_params[:destination_namespace]), import_type: 'bulk_import_group' }
      )
    end

    def source_equals_destination?
      credentials[:url].starts_with?(Settings.gitlab.base_url)
    end

    def validate_destination_namespace(entity_params)
      destination_namespace = entity_params[:destination_namespace]
      source_type = entity_params[:source_type]

      return if destination_namespace.blank?

      group = Group.find_by_full_path(destination_namespace)
      if group.nil? ||
          (source_type == 'group_entity' && !current_user.can?(:create_subgroup, group)) ||
          (source_type == 'project_entity' && !current_user.can?(:import_projects, group))
        raise BulkImports::Error.destination_namespace_validation_failure(destination_namespace)
      end
    end

    def validate_destination_slug(destination_slug)
      return if destination_slug =~ Gitlab::Regex.oci_repository_path_regex

      raise BulkImports::Error.destination_slug_validation_failure
    end

    def validate_destination_full_path(entity_params)
      source_type = entity_params[:source_type]

      full_path = [
        entity_params[:destination_namespace],
        entity_params[:destination_slug] || entity_params[:destination_name]
      ].reject(&:blank?).join('/')

      case source_type
      when 'group_entity'
        return if Namespace.find_by_full_path(full_path).nil?
      when 'project_entity'
        return if Project.find_by_full_path(full_path).nil?
      end

      raise BulkImports::Error.destination_full_path_validation_failure(full_path)
    end

    def user_role(destination_namespace)
      namespace = Namespace.find_by_full_path(destination_namespace)
      # if there is no parent namespace we assume user will be group creator/owner
      return owner_role unless destination_namespace
      return owner_role unless namespace
      return owner_role unless namespace.group_namespace? # user namespace

      membership = current_user.group_members.find_by(source_id: namespace.id) # rubocop:disable CodeReuse/ActiveRecord

      return 'Not a member' unless membership

      Gitlab::Access.human_access(membership.access_level)
    end

    def owner_role
      Gitlab::Access.human_access(Gitlab::Access::OWNER)
    end

    def client
      @client ||= BulkImports::Clients::HTTP.new(
        url: @credentials[:url],
        token: @credentials[:access_token]
      )
    end

    def graphql_client
      @graphql_client ||= BulkImports::Clients::Graphql.new(
        url: @credentials[:url],
        token: @credentials[:access_token]
      )
    end

    def query_type(entity_type)
      if entity_type == 'groups'
        BulkImports::Groups::Graphql::GetGroupQuery.new(context: nil)
      else
        BulkImports::Projects::Graphql::GetProjectQuery.new(context: nil)
      end
    end
  end
end
