class Band < ApplicationRecord
  has_many :band_memberships, dependent: :destroy
  has_many :members, through: :band_memberships, source: :user
  has_many :invitations, dependent: :destroy
  has_many :musics, dependent: :destroy
  has_many :setlists, dependent: :destroy
  has_many :events, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9\-]+\z/ }

  before_validation :generate_slug, on: :create

  def admin_memberships
    band_memberships.where(role: "admin")
  end

  private

  def generate_slug
    return if slug.present?
    base = name.to_s.downcase.gsub(/[^a-z0-9\s]/, "").gsub(/\s+/, "-")
    candidate = base
    counter = 1
    while Band.exists?(slug: candidate)
      candidate = "#{base}-#{counter}"
      counter += 1
    end
    self.slug = candidate
  end
end
