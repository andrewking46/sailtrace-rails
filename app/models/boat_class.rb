class BoatClass < ApplicationRecord
  has_many :boats, dependent: :destroy
end
