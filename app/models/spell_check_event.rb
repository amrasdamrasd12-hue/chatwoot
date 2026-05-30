class SpellCheckEvent < ApplicationRecord
  # Eltafouk: audit log row for the pre-send spell-check guard. One row
  # per spell-check API call; the modal callbacks finalise `decision`
  # so the reports page can break behaviour down per agent.

  DECISIONS = %w[pending no_errors_send corrected sent_original edited unknown].freeze
  SURFACES = %w[dm comments other].freeze

  belongs_to :account
  belongs_to :user, optional: true
  belongs_to :conversation, optional: true
  belongs_to :inbox, optional: true

  has_many :spell_check_fixes, dependent: :destroy_async

  validates :decision, inclusion: { in: DECISIONS }
  validates :surface, inclusion: { in: SURFACES }, allow_nil: true

  scope :in_range, ->(from, to) { where(created_at: from..to) if from && to }
end
