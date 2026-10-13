# frozen_string_literal: true

module Calendar
  # Ideas from Market and Google (index), one taken onto the calendar (create).
  class IdeasController < ApplicationController
    requires_capability "calendar:read", only: :index
    requires_capability "calendar:write", only: :create

    def index
      @ideas = Ideas.new.all
      @planning = Planner.planning?
      @plan_state = Planner.state
    end

    def create
      idea = Ideas.new.find(params[:source].to_s) or return redirect_to(calendar_ideas_path, alert: "That idea is gone or on the calendar already")
      at = params[:on].presence && (Date.parse(params[:on]).in_time_zone.change(hour: 10) rescue nil)
      item = Item.create!(title: idea.title.truncate(200), kind: idea.kind, state: "idea", body: idea.detail, source: idea.source, scheduled_at: at, user: Current.user,
        notes: "From #{idea.origin}")
      item.assign_channels(Channel.connected.pluck(:id)) if item.kind == "social"
      item.save!
      redirect_to back_or(calendar_for(item)), notice: "On the calendar: “#{item.title}”"
    end
  end
end
