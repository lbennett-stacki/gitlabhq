# frozen_string_literal: true

module Spam
  class SpamActionService
    include SpamConstants

    def initialize(spammable:, user:, action:, extra_features: {})
      @target = spammable
      @user = user
      @action = action
      @extra_features = extra_features
    end

    def execute
      return ServiceResponse.success(message: 'Skipped spam check because spam_params was not present') unless spam_params
      return ServiceResponse.success(message: 'Skipped spam check because user was not present') unless user

      if target.supports_recaptcha?
        execute_with_captcha_support
      else
        execute_spam_check
      end
    end

    delegate :check_for_spam?, to: :target

    private

    attr_reader :user, :action, :target, :spam_log, :extra_features

    def spam_params
      Gitlab::RequestContext.instance.spam_params
    end

    def execute_with_captcha_support
      recaptcha_verified = Captcha::CaptchaVerificationService.new(spam_params: spam_params).execute

      if recaptcha_verified
        # If it's a request which is already verified through CAPTCHA,
        # update the spam log accordingly.
        SpamLog.verify_recaptcha!(user_id: user.id, id: spam_params.spam_log_id)
        ServiceResponse.success(message: "CAPTCHA successfully verified")
      else
        execute_spam_check
      end
    end

    def execute_spam_check
      return ServiceResponse.success(message: 'Skipped spam check because user was allowlisted') if allowlisted?(user)
      return ServiceResponse.success(message: 'Skipped spam check because it was not required') unless check_for_spam?(user: user)

      perform_spam_service_check
      ServiceResponse.success(message: "Spam check performed. Check #{target.class.name} spammable model for any errors or CAPTCHA requirement")
    end

    ##
    # In order to be proceed to the spam check process, the target must be
    # a dirty instance, which means it should be already assigned with the new
    # attribute values.
    def ensure_target_is_dirty
      msg = "Target instance of #{target.class.name} must be dirty (must have changes to save)"
      raise(msg) unless target.has_changes_to_save?
    end

    def allowlisted?(user)
      user.try(:gitlab_bot?) || user.try(:gitlab_service_user?)
    end

    ##
    # Performs the spam check using the spam verdict service, and modifies the target model
    # accordingly based on the result.
    def perform_spam_service_check
      ensure_target_is_dirty

      # since we can check for spam, and recaptcha is not verified,
      # ask the SpamVerdictService what to do with the target.
      spam_verdict_service.execute.tap do |result|
        case result
        when BLOCK_USER
          # TODO: improve BLOCK_USER handling, non-existent until now
          # https://gitlab.com/gitlab-org/gitlab/-/issues/329666
          target.spam!
          create_spam_log
        when DISALLOW
          target.spam!
          create_spam_log
        when CONDITIONAL_ALLOW
          # This means "require a CAPTCHA to be solved"
          target.needs_recaptcha!
          create_spam_log
        when OVERRIDE_VIA_ALLOW_POSSIBLE_SPAM
          create_spam_log
        when ALLOW
          target.clear_spam_flags!
        when NOOP
          # spamcheck is not explicitly rendering a verdict & therefore can't make a decision
          target.clear_spam_flags!
        end
      end
    end

    def create_spam_log
      @spam_log = SpamLog.create!(
        {
          user_id: user.id,
          title: target.spam_title,
          description: target.spam_description,
          source_ip: spam_params.ip_address,
          user_agent: spam_params.user_agent,
          noteable_type: noteable_type,
          # Now, all requests are via the API, so hardcode it to true to simplify the logic and API
          # of this service.  See https://gitlab.com/gitlab-org/gitlab-foss/-/merge_requests/2266
          # for original introduction of `via_api` field.
          # See discussion here about possibly deprecating this field:
          # https://gitlab.com/gitlab-org/gitlab-foss/-/merge_requests/2266#note_542527450
          via_api: true
        }
      )

      target.spam_log = spam_log
    end

    def spam_verdict_service
      context = {
        action: action,
        target_type: noteable_type
      }

      options = {
        ip_address: spam_params.ip_address,
        user_agent: spam_params.user_agent,
        referer: spam_params.referer
      }

      SpamVerdictService.new(target: target,
                             user: user,
                             options: options,
                             context: context,
                             extra_features: extra_features
                            )
    end

    def noteable_type
      @notable_type ||= target.class.to_s
    end
  end
end
