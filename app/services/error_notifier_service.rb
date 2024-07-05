class ErrorNotifierService
  class << self
    def notify(error, context = {})
      Rails.logger.error("Error: #{error.message}")
      Rails.logger.error("Full details: #{error.inspect}")
      Rails.logger.error("Context: #{context}")

      # Here you would typically integrate with an error tracking service
      # For example, if using Sentry:
      # Sentry.capture_exception(error, extra: context)

      # Or if using Bugsnag:
      # Bugsnag.notify(error) do |report|
      #   report.add_metadata(:context, context)
      # end

      # For now, we'll just print to console in development
      if Rails.env.development?
        puts "Error: #{error.message}"
        puts "Context: #{context}"
      end
    end
  end
end
