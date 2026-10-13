# frozen_string_literal: true

module Calendar
  module Items
    # The AI writes each channel's text (in the background).
    class DraftsController < Calendar::ApplicationController
      requires_capability "calendar:write", only: :create

      def create
        item = Item.find(params[:item_id])
        return redirect_to(calendar_for(item), alert: Ai.unavailable_reason) unless Calendar.ai?

        item.update_columns(draft_state: "queued", draft_error: nil, updated_at: Time.current)
        DraftJob.perform_later(item, Current.user)
        redirect_to calendar_for(item), notice: "Writing each channel's post: a minute or so"
      end
    end
  end
end
