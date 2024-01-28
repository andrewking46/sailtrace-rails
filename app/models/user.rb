class User < ApplicationRecord
  has_many :boats, dependent: :destroy
  has_many :recordings, dependent: :destroy
end
