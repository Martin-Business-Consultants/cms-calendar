# frozen_string_literal: true

# The AI drafts an item's posts off the request (Calendar::Drafter).
class Calendar::DraftJob < ApplicationJob
  def perform(item, user = nil) = Calendar::Drafter.new(item, user: user).run!
end
