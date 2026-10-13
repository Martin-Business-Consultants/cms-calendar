# frozen_string_literal: true

module Calendar
  # Ideas from Market and Google, the most timely first (index), one taken onto
  # the calendar (create), on the date given, or the one it suggests.
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
      on = params.key?(:on) ? (Date.parse(params[:on].to_s) rescue nil) : idea.on
      item = Item.create!(title: idea.title.truncate(200), kind: idea.kind, state: "idea", body: idea.detail, source: idea.source, scheduled_at: on&.in_time_zone&.change(hour: 10),
        user: Current.user, notes: ["From #{idea.origin}", idea.facts].compact.join(": "))
      item.assign_channels(Channel.connected.pluck(:id)) if item.kind == "social"
      item.save!
      redirect_to back_or(calendar_for(item)), notice: "On the calendar: “#{item.title}”"
    end
  end
end
