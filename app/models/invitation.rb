class Invitation < ApplicationRecord
  belongs_to :band
  belongs_to :invited_by, class_name: "User"

  before_create :generate_token

  scope :pending, -> { where(used_at: nil) }
  scope :used, -> { where.not(used_at: nil) }

  def used?
    used_at.present?
  end

  def mark_used!
    update!(used_at: Time.current)
  end

  private

  def generate_token
    self.token = SecureRandom.urlsafe_base64(32)
  end
end
