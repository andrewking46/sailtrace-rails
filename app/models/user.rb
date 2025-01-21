class User < ApplicationRecord
  has_many :boats, dependent: :destroy
  has_many :recordings, dependent: :destroy
  has_many :sessions, dependent: :destroy
  has_many :access_tokens, dependent: :destroy
  has_many :password_resets, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :yacht_clubs, through: :memberships, source: :organization, source_type: "YachtClub"
  has_many :sailing_teams, through: :memberships, source: :organization, source_type: "SailingTeam"

  validates :username, presence: true, uniqueness: true
  validates :email_address, presence: true, uniqueness: { case_sensitive: false },
                            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, presence: true
  validates :last_name, presence: true

  before_validation :set_username
  before_save :downcase_email

  has_secure_password

  private

  def set_username
    return if username.present?
    self.username = "#{first_name.gsub(/(\W|\d)/, "").downcase}#{last_name.gsub(/(\W|\d)/, "").downcase}"
  end

  def downcase_email
    self.email_address = email_address.downcase
  end
end
