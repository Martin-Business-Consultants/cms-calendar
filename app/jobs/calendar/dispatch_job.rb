# frozen_string_literal: true

# Every minute: sends what's due (Calendar::Item.dispatch_due).
class Calendar::DispatchJob < ApplicationJob
  def perform = Calendar::Item.dispatch_due
end
