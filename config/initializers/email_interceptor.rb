class EmailInterceptor
  def self.delivering_email(message)
    message.subject = "#{message.subject} [#{Rails.env}]"
    message.to = ENV['INTERCEPT_EMAILS_TO'] if Rails.env.staging?
  end
end

ActionMailer::Base.register_interceptor(EmailInterceptor)
