class SailingTeam < ApplicationRecord
  has_many :memberships, as: :organization, dependent: :destroy
  has_many :users, through: :memberships

  has_many :boats, as: :organization, dependent: :nullify

  has_one_attached :burgee

  validates :name, presence: true
end
