class AccessToken < ApplicationRecord
  belongs_to :user
  before_create :generate_tokens

  private

  def generate_tokens
    self.token = SecureRandom.hex(32)
    self.refresh_token = SecureRandom.hex(32)
    self.expires_at = 2.hours.from_now
    self.refresh_token_expires_at = 30.days.from_now
  end
end
