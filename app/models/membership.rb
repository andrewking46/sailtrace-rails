class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :organization, polymorphic: true

  validates :user_id, uniqueness: {
    scope: %i[organization_id organization_type],
    message: "already belongs to this organization."
  }
end
