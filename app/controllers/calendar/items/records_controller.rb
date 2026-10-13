# frozen_string_literal: true

module Calendar
  module Items
    # The draft post or page on the site started for an item, and opened.
    class RecordsController < Calendar::ApplicationController
      requires_capability "calendar:write", only: :create
      before_action :require_content_rights

      def create
        record = @item.start_record!(by: Current.user)
        redirect_to record.is_a?(::Page) ? edit_page_path(record.path) : edit_collection_entry_path(record.collection.slug, record.slug), notice: "Draft started for “#{@item.title}”"
      rescue Calendar::Error, ActiveRecord::RecordInvalid => error
        redirect_to calendar_for(@item), alert: error.message
      end

      private

      def require_content_rights
        @item = Item.find(params[:item_id])
        capability = (@item.kind == "page") ? "pages:write" : "entries:write"
        redirect_to calendar_for(@item), alert: "Your role can't write #{capability.split(":").first}" unless Current.user.can?(capability)
      end
    end
  end
end
