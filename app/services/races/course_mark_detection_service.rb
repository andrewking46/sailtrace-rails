# app/services/races/course_mark_detection_service.rb
# frozen_string_literal: true

module Races
  class CourseMarkDetectionService
    # We assume a Race has many Recordings, each with Maneuvers.
    # We'll cluster those Maneuvers to find potential marks.
    #
    # Then, to offset the mark "inside" the turn:
    #   - For each cluster, we compute an "average heading vector" from the approach
    #     or the sign of the cumulative heading. We push the final mark location
    #     slightly inside that turn (both lat & lon).
    #
    # Constants:
    CLUSTER_RADIUS_METERS  = 20.0
    MIN_SHARE_OF_RECORDINGS = 0.3  # fraction of Race recordings that must confirm the cluster
    TURN_OFFSET_METERS      = 5.0  # how far "inside" the turn we place the mark

    def initialize(race_id)
      @race = Race.find(race_id)
    end

    def call
      return unless @race

      ActiveRecord::Base.transaction do
        @race.course_marks.delete_all

        # 1) Gather maneuvers from all recordings
        candidates = gather_maneuver_candidates

        # 2) Cluster them by proximity
        clusters = cluster_points(candidates)

        # 3) Filter out small clusters, compute final mark location, store
        clusters.each { |cl| process_cluster(cl) }
      end
    rescue => e
      ErrorNotifierService.notify(e, race_id: @race&.id)
    end

    private

    # We want only "big" maneuvers, e.g. absolute heading change >= 80 => likely mark rounding.
    def gather_maneuver_candidates
      # We'll store an Array of Hashes: { lat:, lon:, recording_id:, delta:, direction_sign: }
      # "direction_sign" = +1 if cumulative_heading_change>0 => clockwise turn, -1 if <0 => counterclockwise
      big_ones = Maneuver
                 .where(recording_id: @race.recordings.select(:id))
                 .where("ABS(cumulative_heading_change) >= 80")

      big_ones.find_each(batch_size: 100).map do |m|
        {
          lat: m.latitude.to_f,
          lon: m.longitude.to_f,
          recording_id: m.recording_id,
          direction_sign: (m.cumulative_heading_change >= 0 ? +1 : -1),
          abs_delta: m.cumulative_heading_change.abs,
          maneuver_conf: m.confidence
        }
      end
    end

    # Simple "nearest cluster" approach
    def cluster_points(points)
      clusters = []

      points.each do |pt|
        placed = false

        clusters.each do |cl|
          dist = Gps::DistanceCalculator.distance_in_meters(pt[:lat], pt[:lon], cl[:lat], cl[:lon])
          if dist <= CLUSTER_RADIUS_METERS
            cl[:points] << pt
            placed = true
            break
          end
        end

        unless placed
          clusters << {
            lat: pt[:lat],
            lon: pt[:lon],
            points: [ pt ]
          }
        end
      end

      # refine each cluster (recompute centroid, discard if not enough coverage)
      refine_clusters(clusters)
    end

    def refine_clusters(clusters)
      total_recordings = @race.recordings.count
      final_clusters = []

      clusters.each do |cl|
        # Recompute centroid
        avg_lat = cl[:points].map { |p| p[:lat] }.sum / cl[:points].size
        avg_lon = cl[:points].map { |p| p[:lon] }.sum / cl[:points].size

        distinct_recs = cl[:points].map { |p| p[:recording_id] }.uniq.size
        coverage = distinct_recs.to_f / total_recordings.to_f

        next if coverage < MIN_SHARE_OF_RECORDINGS

        final_clusters << {
          lat: avg_lat,
          lon: avg_lon,
          points: cl[:points],
          coverage: coverage
        }
      end

      final_clusters
    end

    # Takes a final cluster, offsets location "inside" the turn, and saves as CourseMark
    def process_cluster(cluster)
      offset_lat, offset_lon = compute_offset_position(cluster)

      # We can guess mark_type from the average abs_delta
      mark_type = guess_mark_type(cluster[:points])

      CourseMark.create!(
        race: @race,
        latitude:  offset_lat.round(6),
        longitude: offset_lon.round(6),
        confidence: cluster_confidence(cluster),
        mark_type:  mark_type
      )
    end

    # We'll do a naive approach:
    #   - Average the "direction_sign" => if mostly +1 => clockwise turn => offset to the "right"
    #     if mostly -1 => offset to the "left"
    #   - We'll also incorporate an approximate heading approach if we want. For now, we
    #     do a simple lat/lon shift using a small "bearing" assumption.
    def compute_offset_position(cluster)
      direction_sum = cluster[:points].map { |p| p[:direction_sign] }.sum
      sign = direction_sum >= 0 ? +1 : -1

      # Next, we'll shift both lat & lon by a small amount perpendicular to the "average lat/lon".
      # For a real approach, you'd gather approach headings from the boat track near the maneuver.

      # Let's do a simple hack: shift in longitude for sign>0, or in negative longitude for sign<0.
      # 1 degree of longitude ~ 111,111 * cos(latitude) meters
      # 1 degree of latitude  ~ 111,111 meters
      # We'll pick an "azimuth" to the side.
      lat_deg_per_meter = 1.0 / 111_111.0
      lon_deg_per_meter = 1.0 / (111_111.0 * Math.cos(cluster[:lat] * Math::PI / 180.0).abs)

      # We'll shift about TURN_OFFSET_METERS in a perpendicular axis.
      # If sign>0 => shift +some fraction in lon (like "east" for clockwise),
      # if sign<0 => shift -some fraction in lon (like "west" for counter-clockwise),
      # or do a small lat shift. We'll combine them to mimic "diagonal" inside the turn.

      offset_meters = TURN_OFFSET_METERS
      # Let's do half in lat, half in lon => diagonal
      offset_in_lat_m = offset_meters / 2.0
      offset_in_lon_m = offset_meters / 2.0

      new_lat = cluster[:lat] + (sign * offset_in_lat_m * lat_deg_per_meter)
      new_lon = cluster[:lon] + (sign * offset_in_lon_m * lon_deg_per_meter)

      [ new_lat, new_lon ]
    end

    def guess_mark_type(points)
      # If average abs_delta >= 140 => "windward" rounding
      # If 80..140 => "leeward"
      # If 60..80 => maybe "gate" or "offset"
      # This is a naive approach; you can refine further.
      #
      # avg_delta = points.map { |p| p[:abs_delta] }.sum / points.size
      # if avg_delta >= 135
      #   "windward"
      # elsif avg_delta >= 80
      #   "leeward"
      # else
      #   "offset"
      # end
      "unknown"
    end

    def cluster_confidence(cluster)
      # e.g. coverage + average maneuver_conf
      avg_conf = cluster[:points].map { |p| p[:maneuver_conf] }.sum / cluster[:points].size
      combined = cluster[:coverage] + avg_conf
      [ combined * 0.5, 1.0 ].min.round(3) # Weighted average, clamped at 1.0
    end
  end
end
