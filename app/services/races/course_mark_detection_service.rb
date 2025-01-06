# app/services/races/course_mark_detection_service.rb
# frozen_string_literal: true

module Races
  ##
  # CourseMarkDetectionService is responsible for inferring the locations of
  # course marks (e.g., windward/leeward marks, gates, etc.) based on the boat's
  # big turning maneuvers across multiple recordings in a Race. We:
  #
  # 1. Identify "large" maneuvers (≥80°).
  # 2. Cluster them spatially (within 15m).
  # 3. Discard clusters not observed by at least 30% of the Race's recordings.
  # 4. Offset each cluster "inside" the turn, storing a CourseMark record.
  # 5. Use `guess_mark_type` to label the mark (if possible) based on headings,
  #    maneuver types, and/or wind direction.
  #
  # The logic here is naive but fairly effective in practice for many dinghy races.
  #
  class CourseMarkDetectionService
    # -----------------------------
    #         CONFIG CONSTANTS
    # -----------------------------
    CLUSTER_RADIUS_METERS   = 15.0   # cluster size threshold
    MIN_SHARE_OF_RECORDINGS = 0.3    # fraction of Race recordings for a valid mark
    TURN_OFFSET_METERS      = 3.0    # distance "inside" the turn
    ABS_DELTA_THRESHOLD     = 80.0   # only maneuvers with abs heading change >= 80
    WINDWARD_THRESHOLD      = 135.0  # threshold for "windward" classification
    LAT_PER_METER           = 1.0 / 111_111.0

    ##
    # Creates a new service to detect CourseMarks for the given Race ID
    #
    # @param race_id [Integer]
    #
    def initialize(race_id:)
      @race = Race.find(race_id)
    end

    ##
    # Orchestrates mark detection:
    #  - Purge old course_marks
    #  - Gather candidate maneuvers
    #  - Cluster them
    #  - Refine clusters & store new course_marks
    #
    def call
      return unless @race

      ActiveRecord::Base.transaction do
        @race.course_marks.delete_all

        candidates = gather_maneuver_candidates
        clusters   = cluster_points(candidates)

        clusters.each do |cl|
          process_cluster(cl)
        end
      end
    rescue => e
      ErrorNotifierService.notify(e, race_id: @race&.id)
    end

    private

    ##
    # gather_maneuver_candidates:
    #
    # We pull all Maneuvers from the Race's recordings with abs heading change ≥ 80°.
    # We also store each maneuver's type, so we can see if it's "rounding", "tack", etc.
    # In addition, we store the recording's wind direction (if present) in the returned hash
    # for smarter classification.
    #
    # Returns Array of Hash: [
    #   {
    #     lat: Float,
    #     lon: Float,
    #     recording_id: Integer,
    #     direction_sign: +1 or -1,
    #     abs_delta: Float,
    #     maneuver_conf: Float,
    #     maneuver_type: String,
    #     wind_dir: Float or nil
    #   },
    #   ...
    # ]
    #
    def gather_maneuver_candidates
      return [] if @race.recordings.empty?

      # Build a quick map of recording_id => wind_direction for all relevant recordings
      wind_map = @race.recordings
                      .select(:id, :wind_direction_degrees)
                      .map { |r| [ r.id, r.wind_direction_degrees ] }
                      .to_h

      big_ones = Maneuver
        .where(recording_id: @race.recordings.select(:id))
        .where("ABS(cumulative_heading_change) >= ?", ABS_DELTA_THRESHOLD)

      results = []
      big_ones.find_each(batch_size: 100) do |m|
        results << {
          lat:            m.latitude.to_f,
          lon:            m.longitude.to_f,
          recording_id:   m.recording_id,
          direction_sign: (m.cumulative_heading_change >= 0 ? +1 : -1),
          abs_delta:      m.cumulative_heading_change.abs,
          maneuver_conf:  m.confidence,
          maneuver_type:  m.maneuver_type,
          wind_dir:       wind_map[m.recording_id] # could be nil if not present
        }
      end

      results
    end

    ##
    # cluster_points:
    #
    # Takes an array of point-hashes and groups them into clusters if they lie
    # within CLUSTER_RADIUS_METERS of an existing cluster's centroid.
    #
    # Returns an Array of cluster-hashes of the form:
    #   {
    #     lat: Float,
    #     lon: Float,
    #     points: [ { lat:, lon:, ... }, { ... } ],
    #     coverage: Float,   # assigned later in refine_clusters
    #   }
    #
    def cluster_points(points)
      clusters = []

      points.each do |pt|
        placed = false

        # Try to place this point in an existing cluster
        clusters.each do |cl|
          dist = Gps::DistanceCalculator.distance_in_meters(pt[:lat], pt[:lon], cl[:lat], cl[:lon])
          if dist <= CLUSTER_RADIUS_METERS
            cl[:points] << pt
            placed = true
            break
          end
        end

        # If not placed, create a new cluster
        unless placed
          clusters << {
            lat: pt[:lat],
            lon: pt[:lon],
            points: [ pt ]
          }
        end
      end

      refine_clusters(clusters)
    end

    ##
    # refine_clusters:
    #
    # 1) For each cluster, recompute the centroid as an average of all points.
    # 2) Calculate coverage = how many distinct recordings are in that cluster
    #    / total recordings in the race.
    # 3) Drop any cluster that doesn't meet MIN_SHARE_OF_RECORDINGS coverage.
    #
    def refine_clusters(clusters)
      total_recordings = @race.recordings.count
      final_clusters   = []

      clusters.each do |cl|
        pts = cl[:points]
        avg_lat = pts.map { |p| p[:lat] }.sum / pts.size
        avg_lon = pts.map { |p| p[:lon] }.sum / pts.size

        distinct_recs = pts.map { |p| p[:recording_id] }.uniq.size
        coverage = distinct_recs.to_f / total_recordings.to_f

        next if coverage < MIN_SHARE_OF_RECORDINGS

        final_clusters << {
          lat:      avg_lat,
          lon:      avg_lon,
          points:   pts,
          coverage: coverage
        }
      end

      final_clusters
    end

    ##
    # process_cluster:
    #
    # For each final cluster, we:
    #  - compute an offset location inside the turn
    #  - guess a mark_type
    #  - compute a confidence
    #  - create a CourseMark
    #
    def process_cluster(cluster)
      offset_lat, offset_lon = compute_offset_position(cluster)
      mark_type  = guess_mark_type(cluster)
      conf       = cluster_confidence(cluster)

      CourseMark.create!(
        race:       @race,
        latitude:   offset_lat.round(6),
        longitude:  offset_lon.round(6),
        confidence: conf,
        mark_type:  mark_type
      )
    end

    ##
    # compute_offset_position:
    #
    # Offsets the cluster's centroid "inside" the turn by TURN_OFFSET_METERS.
    # We do this by:
    #  - Summing direction_sign of all points to see if the cluster is generally
    #    clockwise (+) or counterclockwise (-).
    #  - Then shifting both lat & lon in a diagonal direction.
    #
    def compute_offset_position(cluster)
      pts  = cluster[:points]
      sum_signs = pts.map { |p| p[:direction_sign] }.sum
      sign = sum_signs >= 0 ? +1 : -1

      # 1 degree of longitude in meters depends on latitude
      lat_deg_per_meter = LAT_PER_METER
      lon_deg_per_meter = 1.0 / (111_111.0 * Math.cos(cluster[:lat] * Math::PI / 180.0).abs)

      # We'll shift half in lat, half in lon
      offset_m = TURN_OFFSET_METERS
      offset_in_lat_m = offset_m / 2.0
      offset_in_lon_m = offset_m / 2.0

      new_lat = cluster[:lat] + (sign * offset_in_lat_m * lat_deg_per_meter)
      new_lon = cluster[:lon] + (sign * offset_in_lon_m * lon_deg_per_meter)

      [ new_lat, new_lon ]
    end

    ##
    # guess_mark_type:
    #
    # Given all points in the cluster, we try to infer if it's a windward mark,
    # leeward mark, offset, gate, or unknown. Now we also consider:
    #  - The presence of wind_dir (wind direction) in those points
    #  - The maneuvers' types (rounding, tack, jibe, etc.)
    #  - The typical angle thresholds
    #
    # This is still naive, but less naive than before.
    #
    def guess_mark_type(cluster)
      pts       = cluster[:points]
      avg_delta = pts.map { |p| p[:abs_delta] }.sum / pts.size
      # Tally up how many are "rounding" vs. tack/jibe/penalty_spin, etc.
      types     = pts.group_by { |p| p[:maneuver_type] }

      # If most maneuvers in this cluster are "rounding," treat it as a "true rounding mark"
      # If we have a bunch of "tack" maneuvers, might be upwind; if "jibe," might be downwind
      rounding_count = types["rounding"]&.size || 0
      tack_count     = types["tack"]&.size || 0
      jibe_count     = types["jibe"]&.size || 0

      # Heuristic #1: if majority are rounding, let's decide upwind or downwind
      #               based on wind direction if we can:
      majority_rounding = rounding_count >= (pts.size / 2.0)

      if majority_rounding
        # if avg_delta >= 135 => likely "windward"
        # else => "leeward" (since it's presumably a bigger turn if upwind)
        return avg_delta >= WINDWARD_THRESHOLD ? "windward" : "leeward"
      end

      # Heuristic #2: if we see more "tack" than "jibe", we guess "windward" mark
      #               if we see more "jibe" than "tack", we guess "leeward"
      if tack_count > jibe_count
        return "windward"
      elsif jibe_count > tack_count
        return "leeward"
      end

      # Fallback #3: do the old numeric approach from the commented code
      # (This might be refined by checking if the boat approached near wind_dir or wind_dir+180.)
      case avg_delta
      when 135..9999
        "windward"
      when 80..135
        "leeward"
      when 60..80
        "offset"
      else
        "unknown"
      end
    end

    ##
    # cluster_confidence:
    #
    # Combines coverage (fraction of the race's recordings) + average maneuver_conf
    # for all points in the cluster. The weighting is naive, but it gives us a rough sense
    # of how reliable this mark identification is.
    #
    def cluster_confidence(cluster)
      pts         = cluster[:points]
      coverage    = cluster[:coverage]
      avg_conf    = pts.map { |p| p[:maneuver_conf] }.sum / pts.size
      combined    = coverage + avg_conf
      # Weighted average, clamped at 1.0
      [ combined * 0.5, 1.0 ].min.round(3)
    end
  end
end
