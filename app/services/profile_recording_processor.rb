require "memory_profiler"

# Simulate processing a large recording
recording = Recording.create!(name: "Test Recording", started_at: Time.current, time_zone: "UTC", boat: Boat.first,
                              user: User.first)

# Generate a large number of locations
100.times do |_i|
  recording.recorded_locations.create!(
    latitude: 40.7128 + (rand - 0.5) * 0.1,
    longitude: -74.0060 + (rand - 0.5) * 0.1,
    accuracy: 3,
    recorded_at: Time.current
  )
end

report = MemoryProfiler.report do
  RecordingProcessorJob.perform_now(recording.id)
end

# Generate the report
report.pretty_print(to_file: "memory_profile_report.txt")
