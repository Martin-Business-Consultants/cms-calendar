# frozen_string_literal: true

module Calendar
  module Api
    # GET /api/calendar/ideas; POST {"source","at"} takes one onto the calendar as an idea.
    class IdeasController < BaseController
      requires_capability "calendar:read", only: :index
      requires_capability "calendar:write", only: :create

      def index
        render json: {ideas: Ideas.new.all.map(&:to_h)}
      end

      def create
        idea = Ideas.new.find(params[:source].to_s) or return refuse("That idea is gone or on the calendar already", status: :not_found)
        @item = Item.create!(title: idea.title.truncate(200), kind: idea.kind, state: "idea", body: idea.detail, source: idea.source, user: Current.user,
          scheduled_at: params[:at].presence && Time.zone.parse(params[:at].to_s), notes: "From #{idea.origin}")
        render "calendar/api/items/show", status: :created
      end
    end
  end
end
