class AuditTemplate < ApplicationRecord
  # Associations
  has_many :questions, -> { order(:sequence) }, dependent: :destroy
  has_many :audit_sessions, dependent: :restrict_with_error
  has_many :responses, through: :audit_sessions

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :estimated_duration_minutes, presence: true, numericality: { greater_than: 0 }
  validates :default_voice, presence: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :with_questions, -> { joins(:questions).distinct }

  # Callbacks
  before_validation :set_defaults, on: :create

  # Instance methods
  def total_questions
    questions.count
  end

  def average_completion_time
    completed_sessions = audit_sessions.completed.where.not(completed_at: nil, started_at: nil)
    return estimated_duration_minutes if completed_sessions.empty?

    total_duration = completed_sessions.sum { |session| (session.completed_at - session.started_at).to_i }
    (total_duration / completed_sessions.count / 60.0).round(1) # Return in minutes
  end

  def completion_rate
    total_sessions = audit_sessions.count
    return 0 if total_sessions.zero?

    completed_sessions = audit_sessions.completed.count
    (completed_sessions.to_f / total_sessions * 100).round(1)
  end

  def next_question_for_session(session)
    questions.where("sequence > ?", session.current_question_index).first
  end

  def can_be_deleted?
    audit_sessions.empty?
  end

  private

  def set_defaults
    self.active = true if active.nil?
    self.default_voice ||= "en-US-Neural2-C"
    self.estimated_duration_minutes ||= 15
  end
end
