class Boat < ApplicationRecord
  belongs_to :boat_class
  belongs_to :user, default: -> { Current.user }
  has_many :recordings, dependent: :destroy
  belongs_to :organization, polymorphic: true, optional: true
end
