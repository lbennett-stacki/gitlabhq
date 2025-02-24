# frozen_string_literal: true

module API
  class MlModelPackages < ::API::Base
    include APIGuard
    include ::API::Helpers::Authentication

    ML_MODEL_PACKAGES_REQUIREMENTS = {
      model_name: API::NO_SLASH_URL_PART_REGEX,
      file_name: API::NO_SLASH_URL_PART_REGEX
    }.freeze

    ALLOWED_STATUSES = %w[default hidden].freeze

    feature_category :mlops
    urgency :low

    after_validation do
      require_packages_enabled!
      authenticate_non_get!

      not_found! unless can?(current_user, :read_model_registry, user_project)
    end

    authenticate_with do |accept|
      accept.token_types(:personal_access_token, :deploy_token, :job_token)
            .sent_through(:http_token)
    end

    helpers do
      include ::API::Helpers::PackagesHelpers
      include ::API::Helpers::Packages::BasicAuthHelpers

      def project
        authorized_user_project
      end

      def max_file_size_exceeded?
        project.actual_limits.exceeded?(:ml_model_max_file_size, params[:file].size)
      end
    end

    params do
      requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the project'
    end

    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      namespace ':id/packages/ml_models' do
        params do
          requires :model_name, type: String, desc: 'Model name', regexp: Gitlab::Regex.ml_model_name_regex,
            file_path: true
          requires :model_version, type: String, desc: 'Model version',
            regexp: Gitlab::Regex.ml_model_version_regex
          requires :file_name, type: String, desc: 'Package file name',
            regexp: Gitlab::Regex.ml_model_file_name_regex, file_path: true
          optional :status, type: String, values: ALLOWED_STATUSES, desc: 'Package status'
        end
        namespace ':model_name/*model_version/:file_name', requirements: ML_MODEL_PACKAGES_REQUIREMENTS do
          desc 'Workhorse authorize model package file' do
            detail 'Introduced in GitLab 16.1'
            success code: 200
            failure [
              { code: 401, message: 'Unauthorized' },
              { code: 403, message: 'Forbidden' },
              { code: 404, message: 'Not Found' }
            ]
            tags %w[ml_model_registry]
          end
          put 'authorize' do
            authorize_workhorse!(subject: project, maximum_size: project.actual_limits.ml_model_max_file_size)
          end

          desc 'Workhorse upload model package file' do
            detail 'Introduced in GitLab 16.2'
            success code: 201
            failure [
              { code: 401, message: 'Unauthorized' },
              { code: 403, message: 'Forbidden' },
              { code: 404, message: 'Not Found' }
            ]
            tags %w[ml_model_registry]
          end
          params do
            requires :file,
              type: ::API::Validations::Types::WorkhorseFile,
              desc: 'The package file to be published (generated by Multipart middleware)',
              documentation: { type: 'file' }
          end
          put do
            authorize_upload!(project)

            bad_request!('File is too large') if max_file_size_exceeded?

            create_package_file_params = declared(params).merge(
              build: current_authenticated_job,
              package_name: params[:model_name],
              package_version: params[:model_version]
            )

            package_file = ::Packages::MlModel::CreatePackageFileService
                             .new(project, current_user, create_package_file_params)
                             .execute

            bad_request!('Package creation failed') unless package_file

            created!
          rescue ObjectStorage::RemoteStoreError => e
            Gitlab::ErrorTracking.track_exception(e, extra: { file_name: params[:file_name], project_id: project.id })

            forbidden!
          end

          desc 'Download an ml_model package file' do
            detail 'This feature was introduced in GitLab 16.2'
            success code: 200
            failure [
              { code: 401, message: 'Unauthorized' },
              { code: 403, message: 'Forbidden' },
              { code: 404, message: 'Not Found' }
            ]
            tags %w[ml_model_registry]
          end
          get do
            authorize_read_package!(project)

            package = ::Packages::MlModel::PackageFinder.new(project)
                                                        .execute!(params[:model_name], params[:model_version])
            package_file = ::Packages::PackageFileFinder.new(package, params[:file_name]).execute!

            present_package_file!(package_file)
          end
        end
      end
    end
  end
end
