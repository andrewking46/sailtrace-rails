# frozen_string_literal: true

module Gps
  # VisvalingamWhyatt implements the Visvalingam-Whyatt algorithm for path simplification.
  # It processes a list of GPS points and returns a simplified list based on the target reduction.
  class VisvalingamWhyatt
    # Initialize with a list of points and target reduction percentage.
    #
    # @param points [Array<Hash>] Array of points, each with :latitude, :longitude, and :id.
    # @param target_reduction [Float] Fraction of points to remove (0.0 to 1.0).
    def initialize(points, target_reduction: 0.5)
      @points = points.dup  # Duplicate to prevent side-effects
      @target_reduction = target_reduction
      initialize_linked_list
      initialize_areas
    end

    # Executes the simplification algorithm.
    #
    # @return [Array<Hash>] Simplified array of points.
    def simplify
      return @points if @points.size <= 2

      points_to_remove = (@points.size * @target_reduction).ceil

      points_to_remove.times do
        min_area_node = find_min_area_node
        break unless min_area_node

        # Remove the node with the smallest area.
        min_area_node.remove

        # Recalculate areas for the neighbors.
        min_area_node.prev_node.recalculate_area if min_area_node.prev_node
        min_area_node.next_node.recalculate_area if min_area_node.next_node
      end

      # Extract the remaining points from the linked list.
      extract_points
    end

    private

    # Represents a node in the doubly linked list, holding a point and its area.
    class Node
      attr_accessor :point, :area, :prev_node, :next_node

      # Initialize with a point.
      #
      # @param point [Hash] Point data with :latitude, :longitude, and :id.
      def initialize(point)
        @point = point
        @area = nil
        @prev_node = nil
        @next_node = nil
      end

      # Calculates the triangle area formed by this node and its immediate neighbors.
      #
      # @return [Float] Absolute area of the triangle, or nil if neighbors are missing.
      def calculate_area
        return nil unless @prev_node && @next_node
        return nil if @prev_node.point.nil? || @next_node.point.nil?

        p1 = @prev_node.point
        p2 = @point
        p3 = @next_node.point

        ((p2[:longitude] - p1[:longitude]) * (p3[:latitude] - p1[:latitude]) -
         (p3[:longitude] - p1[:longitude]) * (p2[:latitude] - p1[:latitude])).abs / 2.0
      end

      # Recalculates the area based on current neighbors.
      #
      # @return [Float] Updated area value.
      def recalculate_area
        @area = calculate_area
      end

      # Removes this node from the linked list.
      def remove
        @prev_node.next_node = @next_node
        @next_node.prev_node = @prev_node
        @prev_node = nil
        @next_node = nil
      end
    end

    # Initializes a doubly linked list for the points.
    def initialize_linked_list
      @head = Node.new(nil)  # Dummy head
      @tail = Node.new(nil)  # Dummy tail
      @head.next_node = @tail
      @tail.prev_node = @head

      @points.each do |point|
        node = Node.new(point)
        node.prev_node = @tail.prev_node
        node.next_node = @tail
        @tail.prev_node.next_node = node
        @tail.prev_node = node
      end
    end

    # Initializes area calculations for all applicable nodes.
    def initialize_areas
      current = @head.next_node
      while current && current.next_node != @tail
        current.recalculate_area
        current = current.next_node
      end
    end

    # Finds the node with the smallest area.
    #
    # @return [Node, nil] The node with the smallest area, or nil if none found.
    def find_min_area_node
      min_node = nil
      current = @head.next_node
      while current && current.next_node != @tail
        if current.area && (min_node.nil? || current.area < min_node.area)
          min_node = current
        end
        current = current.next_node
      end
      min_node
    end

    # Extracts the remaining points from the linked list into an array.
    #
    # @return [Array<Hash>] Simplified array of points.
    def extract_points
      simplified = []
      current = @head.next_node
      while current && current != @tail
        simplified << current.point
        current = current.next_node
      end
      simplified
    end
  end
end
