# frozen_string_literal: true

module Gitlab
  module Checks
    module FileSizeCheck
      class AnyOversizedBlob
        def initialize(project:, changes:, file_size_limit_megabytes:)
          @project = project
          @newrevs = changes.pluck(:newrev).compact # rubocop:disable CodeReuse/ActiveRecord just plucking from an array
          @file_size_limit_megabytes = file_size_limit_megabytes
        end
        attr_reader :project, :newrevs, :file_size_limit_megabytes

        def find!(timeout: nil)
          blobs = project.repository.new_blobs(newrevs, dynamic_timeout: timeout)

          blobs.find do |blob|
            ::Gitlab::Utils.bytes_to_megabytes(blob.size) > file_size_limit_megabytes
          end
        end
      end
    end
  end
end
