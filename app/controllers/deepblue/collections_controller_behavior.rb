# frozen_string_literal: true

module Deepblue

  module CollectionsControllerBehavior

    ## email

    def email_rds_create
      curation_concern.email_rds_create( current_user: current_user,
                                         event_note: "created by #{curation_concern.depositor}" )
    end

    def email_rds_destroy
      curation_concern.email_rds_destroy( current_user: current_user )
    end

    def email_rds_publish
      curation_concern.email_rds_publish( current_user: current_user )
    end

    def email_rds_unpublish
      curation_concern.email_rds_unpublish( current_user: current_user )
    end

    ## end email

    ## Provenance log

    def provenance_log_create
      curation_concern.provenance_create( current_user: current_user, event_note: default_event_note )
    end

    def provenance_log_destroy
      curation_concern.provenance_destroy( current_user: current_user, event_note: default_event_note )
    end

    def provenance_log_publish
      curation_concern.provenance_publish( current_user: current_user, event_note: default_event_note )
    end

    def provenance_log_unpublish
      curation_concern.provenance_unpublish( current_user: current_user, event_note: default_event_note )
    end

    def provenance_log_update_after
      curation_concern.provenance_log_update_after( current_user: current_user,
                                                    event_note: default_event_note,
                                                    update_attr_key_values: @update_attr_key_values )
    end

    def provenance_log_update_before
      @update_attr_key_values = curation_concern.provenance_log_update_before( form_params: params[params_key].dup )
    end

    ## end Provenance log

    ## visibility / publish

    def visiblity_changed
      if visibility_to_private?
        mark_as_set_to_private
      elsif visibility_to_public?
        mark_as_set_to_public
      end
    end

    def visibility_changed_update
      if curation_concern.private? && @visibility_changed_to_private
        provenance_log_unpublish
        email_rds_unpublish
      elsif curation_concern.public? && @visibility_changed_to_public
        provenance_log_publish
        email_rds_publish
      end
    end

    def visibility_to_private?
      return false if curation_concern.private?
      params[params_key]['visibility'] == Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
    end

    def visibility_to_public?
      return false if curation_concern.public?
      params[params_key]['visibility'] == Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
    end

    def mark_as_set_to_private
      @visibility_changed_to_public = false
      @visibility_changed_to_private = true
    end

    def mark_as_set_to_public
      @visibility_changed_to_public = true
      @visibility_changed_to_private = false
    end

    ## end visibility / publish

  end

end
