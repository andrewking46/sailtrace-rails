class User < ApplicationRecord
  has_many :boats, dependent: :destroy
  has_many :recordings, dependent: :destroy
  has_many :sessions, dependent: :destroy

  has_secure_password
end
