class User < ApplicationRecord
  has_many :boats, dependent: :destroy
  has_many :recordings, dependent: :destroy
  has_many :sessions, dependent: :destroy
  has_many :access_tokens, dependent: :destroy

  validates :username, presence: true, uniqueness: true
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, presence: true
  validates :last_name, presence: true

  has_secure_password
end
