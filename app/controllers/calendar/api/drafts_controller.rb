# frozen_string_literal: true

module Calendar
  module Api
    # POST /api/calendar/items/:id/draft: the AI writes each channel's text (a minute or so; read the item back).
    class DraftsController < BaseController
      requires_capability "calendar:write", only: :create

      def create
        @item = Item.find(params[:item_id])
        return refuse(::Ai.unavailable_reason.to_s) unless Calendar.ai?

        @item.update_columns(draft_state: "queued", draft_error: nil, updated_at: Time.current)
        DraftJob.perform_later(@item, Current.user)
        render "calendar/api/items/show", status: :accepted
      end
    end
  end
end
