class BoatClass < ApplicationRecord
  has_many :boats, dependent: :destroy
  has_many :races
end
