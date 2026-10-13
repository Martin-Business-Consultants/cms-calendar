# frozen_string_literal: true

require_relative "lib/calendar/version"

Gem::Specification.new do |spec|
  spec.name = "calendar"
  spec.version = Calendar::VERSION
  spec.summary = "A content calendar for Libre Publish: posts, pages and social posts planned from Market, drafted by the AI, published to Facebook, Instagram, LinkedIn, X and Google Business Profile"
  spec.authors = ["Martin Business Consultants"]
  spec.license = "FSL-1.1-MIT"
  spec.files = Dir["{app,config,db,lib}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
