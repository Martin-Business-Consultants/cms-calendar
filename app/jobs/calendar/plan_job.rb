# frozen_string_literal: true

# The AI plans a stretch of the calendar off the request (Calendar::Planner).
class Calendar::PlanJob < ApplicationJob
  def perform(from, to, per_week, user = nil) = Calendar::Planner.new(from: from, to: to, per_week: per_week, user: user).run!
end
