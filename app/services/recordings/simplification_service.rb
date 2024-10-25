# frozen_string_literal: true

module Recordings
  # SimplificationService applies the Visvalingam-Whyatt algorithm to simplify the path
  class SimplificationService
    def initialize(recording)
      @recording = recording
    end

    def process
      # Apply the Visvalingam-Whyatt algorithm
      simplifier = Gps::VisvalingamWhyatt.new(@recording)
      simplifier.simplify

      # Log the results of the simplification
      log_simplification_results
    end

    private

    # Log the results of the simplification process
    def log_simplification_results
      original_count = @recording.recorded_locations.count
      simplified_count = @recording.recorded_locations.not_simplified.count
      Rails.logger.info "Simplified #{original_count} points to #{simplified_count} points"
    end
  end
end
