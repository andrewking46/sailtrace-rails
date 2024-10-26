# frozen_string_literal: true

module Gps
  # VisvalingamWhyatt implements the Visvalingam-Whyatt algorithm for path simplification
  # This version works directly with the database to minimize memory usage
  class VisvalingamWhyatt
    BATCH_SIZE = 200  # Number of points to process in each batch

    # @param recording [Recording] The recording object containing the path to simplify
    def initialize(recording)
      @recording = recording
    end

    # Simplify the path to the target percentage of original points
    # @param target_percentage [Float] The desired percentage of points to keep (0.0 to 1.0)
    def simplify(target_percentage: 0.5)
      target_size = (@recording.recorded_locations.count * target_percentage).ceil
      areas = initialize_areas

      # Continue removing points until we reach the target size
      while areas.size > target_size
        min_area = areas.min_by(&:area)
        areas.delete(min_area)
        update_adjacent_areas(areas, min_area.index)
      end

      mark_simplified_points(areas)
    end

    private

    # Initialize area calculations for all points
    # @return [Array<Area>] Array of Area objects for each point
    def initialize_areas
      areas = []
      @recording.recorded_locations
                .select(:id, :adjusted_latitude, :adjusted_longitude)
                .order(:recorded_at)
                .find_in_batches(batch_size: BATCH_SIZE).with_index do |batch, batch_index|
        batch.each_with_index do |curr, index|
          next if index == 0 || index == batch.size - 1
          prev = batch[index - 1]
          nxt = batch[index + 1]
          area = calculate_triangle_area(prev, curr, nxt)
          areas << Area.new(curr.id, area, (batch_index * BATCH_SIZE) + index, curr.adjusted_latitude, curr.adjusted_longitude)
        end
      end
      areas
    end

    # Update areas of adjacent points after removing a point
    # @param areas [Array<Area>] Current array of Area objects
    # @param index [Integer] Index of the removed point
    def update_adjacent_areas(areas, index)
      [ -1, 0, 1 ].each do |offset|
        adj_index = index + offset
        next if adj_index.negative? || adj_index >= areas.size

        prev = areas[adj_index - 1]
        curr = areas[adj_index]
        nxt = areas[adj_index + 1]

        next if prev.nil? || nxt.nil?

        new_area = calculate_triangle_area(prev, curr, nxt)
        curr.area = new_area
      end
    end

    # Calculate the area of the triangle formed by three points
    # @param p1 [RecordedLocation] First point
    # @param p2 [RecordedLocation] Second point
    # @param p3 [RecordedLocation] Third point
    # @return [Float] Area of the triangle
    def calculate_triangle_area(p1, p2, p3)
      # Use Floats for better performance
      ((p2.adjusted_longitude.to_f - p1.adjusted_longitude.to_f) * (p3.adjusted_latitude.to_f - p1.adjusted_latitude.to_f) -
       (p3.adjusted_longitude.to_f - p1.adjusted_longitude.to_f) * (p2.adjusted_latitude.to_f - p1.adjusted_latitude.to_f)).abs / 2.0
    end

    # Mark points as simplified in the database
    # @param areas [Array<Area>] Array of Area objects for points to keep
    def mark_simplified_points(areas)
      kept_ids = areas.map(&:id)
      @recording.recorded_locations.where.not(id: kept_ids).update_all(is_simplified: true)
    end
  end

  # Simple class to hold area information for a point
  class Area
    attr_reader :id, :index, :adjusted_latitude, :adjusted_longitude
    attr_accessor :area

    def initialize(id, area, index, adjusted_latitude, adjusted_longitude)
      @id = id
      @area = area
      @index = index
      @adjusted_latitude = adjusted_latitude
      @adjusted_longitude = adjusted_longitude
    end
  end
end
