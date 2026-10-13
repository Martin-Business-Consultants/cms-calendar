# frozen_string_literal: true

module Calendar
  # The AI plans a stretch of the calendar (in the background).
  class PlansController < ApplicationController
    requires_capability "calendar:write", only: :create

    def create
      return redirect_to(calendar_ideas_path, alert: Ai.unavailable_reason) unless Calendar.ai?
      return redirect_to(calendar_ideas_path, notice: "Already planning") if Planner.planning?

      from = (Date.parse(params[:from].to_s) rescue Date.tomorrow)
      to = (Date.parse(params[:to].to_s) rescue from + 27)
      to = from + 27 if to < from || to > from + 92
      Setting.set(Settings::KEY, "planning_since" => Time.current.iso8601, "plan_error" => nil)
      PlanJob.perform_later(from.iso8601, to.iso8601, params[:per_week].presence || 3, Current.user)
      redirect_to calendar_ideas_path, notice: "Planning #{l from, format: :long} to #{l to, format: :long}: a minute or so"
    end
  end
end
