class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :band_memberships, dependent: :destroy
  has_many :bands, through: :band_memberships
  has_many :invitations, foreign_key: :invited_by_id, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: { case_sensitive: false },
                             format: { with: URI::MailTo::EMAIL_REGEXP }

  def member_of?(band)
    band_memberships.exists?(band: band)
  end

  def admin_of?(band)
    band_memberships.exists?(band: band, role: "admin")
  end
end
