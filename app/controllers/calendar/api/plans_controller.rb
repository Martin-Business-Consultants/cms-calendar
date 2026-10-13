# frozen_string_literal: true

module Calendar
  module Api
    # POST /api/calendar/plans {"from","to","per_week"}: the AI plans that stretch as ideas (a minute or so).
    class PlansController < BaseController
      requires_capability "calendar:write", only: :create

      def create
        return refuse(::Ai.unavailable_reason.to_s) unless Calendar.ai?
        return refuse("Already planning") if Planner.planning?

        from = (Date.parse(params[:from].to_s) rescue Date.tomorrow)
        to = (Date.parse(params[:to].to_s) rescue from + 27)
        to = from + 27 if to < from || to > from + 92
        Setting.set(Settings::KEY, "planning_since" => Time.current.iso8601, "plan_error" => nil)
        PlanJob.perform_later(from.iso8601, to.iso8601, params[:per_week].presence || 3, Current.user)
        render json: {status: "planning", from: from, to: to}, status: :accepted
      end
    end
  end
end
