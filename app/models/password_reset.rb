class PasswordReset < ApplicationRecord
  belongs_to :user

  has_secure_token :reset_token

  before_create :set_expiration
  after_create :send_reset_email

  validates :user_id, presence: true
  validate :no_recent_reset, on: :create
  validate :max_active_resets_per_user, on: :create

  scope :recent, -> { where("created_at > ?", 15.minutes.ago) }
  scope :pending, -> { where(used_at: nil).where("expires_at > ?", Time.current) }

  def self.find_by_token(token)
    pending.find_by(reset_token: token)
  end

  def expired?
    expires_at < Time.current
  end

  def update_password(password_params)
    return false if expired?

    if user.update(password_params)
      use!
      true
    else
      errors.add(:base, user.errors.full_messages)
      false
    end
  end

  def use!
    update!(used_at: Time.current)
  end

  private

  def set_expiration
    self.expires_at = 2.hours.from_now
  end

  def send_reset_email
    UserMailer.password_reset(user, reset_token).deliver_later
  end

  def no_recent_reset
    return unless user.password_resets.recent.exists?

    errors.add(:base, "Please wait before requesting another password reset")
  end

  def max_active_resets_per_user
    return unless user.password_resets.pending.count >= 3

    errors.add(:base, "Too many active reset requests")
  end
end
