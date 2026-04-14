class BandMembership < ApplicationRecord
  belongs_to :user
  belongs_to :band

  ROLES = %w[admin member].freeze

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :band_id }
end
