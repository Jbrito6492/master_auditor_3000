class User < ApplicationRecord
  # Associations
  has_many :audit_sessions, dependent: :destroy
  has_many :responses, through: :audit_sessions
  has_many :audit_insights, through: :audit_sessions

  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :preferred_language, inclusion: { in: %w[en-US es-ES fr-FR de-DE it-IT pt-BR ja-JP ko-KR zh-CN] }
  validates :preferred_voice, presence: true

  # Scopes
  scope :speech_enabled, -> { where(speech_enabled: true) }
  scope :recent_audits, -> { where('last_audit_at > ?', 30.days.ago) }

  # Callbacks
  before_validation :set_defaults, on: :create

  # Instance methods
  def full_name
    name.presence || email.split('@').first.humanize
  end

  def recent_audit_sessions(limit = 10)
    audit_sessions.includes(:audit_template, :responses)
                  .order(started_at: :desc)
                  .limit(limit)
  end

  def completed_audits_count
    audit_sessions.completed.count
  end

  def average_audit_duration
    completed_sessions = audit_sessions.completed.where.not(completed_at: nil, started_at: nil)
    return 0 if completed_sessions.empty?
    
    total_duration = completed_sessions.sum { |session| (session.completed_at - session.started_at).to_i }
    total_duration / completed_sessions.count / 60.0 # Return in minutes
  end

  private

  def set_defaults
    self.preferred_voice ||= 'en-US-Neural2-C'
    self.preferred_language ||= 'en-US'
    self.speech_enabled = true if speech_enabled.nil?
  end
end
