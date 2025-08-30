class AuditSession < ApplicationRecord
  # Associations
  belongs_to :user, optional: true
  belongs_to :audit_template
  has_many :responses, dependent: :destroy
  has_one :audit_insight, dependent: :destroy

  # Enums
  enum :status, {
    started: 0,
    in_progress: 1,
    completed: 2,
    abandoned: 3
  }

  # Validations
  validates :session_token, presence: true, uniqueness: true
  validates :current_question_index, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :preferred_voice, presence: true

  # Scopes
  scope :anonymous, -> { where(user: nil) }
  scope :recent, -> { where('created_at > ?', 30.days.ago) }
  scope :active, -> { where(status: [:started, :in_progress]) }
  scope :by_template, ->(template) { where(audit_template: template) }

  # Callbacks
  before_validation :generate_session_token, on: :create, if: -> { session_token.blank? }
  before_validation :set_defaults, on: :create
  after_update :check_completion_status
  after_create :set_started_at

  # Instance methods
  def anonymous?
    user.nil?
  end

  def current_question
    audit_template.questions.find_by(sequence: current_question_index + 1)
  end

  def next_question
    audit_template.questions.where('sequence > ?', current_question_index).first
  end

  def previous_question
    return nil if current_question_index <= 0
    audit_template.questions.find_by(sequence: current_question_index)
  end

  def total_questions
    audit_template.questions.count
  end

  def progress_percentage
    return 0 if total_questions.zero?
    (current_question_index.to_f / total_questions * 100).round(1)
  end

  def questions_remaining
    [total_questions - current_question_index, 0].max
  end

  def duration_in_minutes
    return 0 unless started_at && (completed_at || Time.current)
    
    end_time = completed_at || Time.current
    ((end_time - started_at) / 60.0).round(1)
  end

  def can_advance?
    current_question_index < total_questions
  end

  def advance_to_next_question!
    return false unless can_advance?
    
    increment!(:current_question_index)
    update!(status: :in_progress) if started?
    
    # Check if we've completed all questions
    complete! if current_question_index >= total_questions
    
    true
  end

  def response_for_question(question)
    responses.find_by(question: question)
  end

  def has_response_for_question?(question)
    response_for_question(question).present?
  end

  def all_questions_answered?
    audit_template.questions.all? { |q| has_response_for_question?(q) }
  end

  def completion_rate
    answered_questions = responses.count
    return 0 if total_questions.zero?
    (answered_questions.to_f / total_questions * 100).round(1)
  end

  def can_be_resumed?
    started? || in_progress?
  end

  def time_since_last_activity
    last_activity = [responses.maximum(:responded_at), updated_at].compact.max
    return nil unless last_activity
    
    Time.current - last_activity
  end

  def should_be_abandoned?
    return false unless can_be_resumed?
    
    time_since_last_activity && time_since_last_activity > 1.hour
  end

  def complete!
    update!(
      status: :completed,
      completed_at: Time.current
    )
    
    # Update user's last audit time
    user&.update(last_audit_at: completed_at)
    
    # Trigger insight generation
    generate_insights_async
  end

  def abandon!
    update!(status: :abandoned)
  end

  def restart!
    update!(
      status: :started,
      current_question_index: 0,
      started_at: Time.current,
      completed_at: nil
    )
    
    # Clear existing responses if restarting
    responses.destroy_all
    audit_insight&.destroy
  end

  # Class methods
  def self.generate_token
    loop do
      token = SecureRandom.urlsafe_base64(32)
      break token unless exists?(session_token: token)
    end
  end

  def self.cleanup_abandoned_sessions
    # Clean up sessions that haven't been active for more than 24 hours
    where(status: [:started, :in_progress])
      .where('updated_at < ?', 24.hours.ago)
      .find_each(&:abandon!)
  end

  private

  def generate_session_token
    self.session_token = self.class.generate_token
  end

  def set_defaults
    self.status ||= :started
    self.current_question_index ||= 0
    self.preferred_voice ||= user&.preferred_voice || audit_template&.default_voice || 'en-US-Neural2-C'
    self.speech_enabled = user&.speech_enabled if speech_enabled.nil?
    self.speech_enabled = true if speech_enabled.nil?
  end

  def set_started_at
    self.started_at ||= Time.current
    save if changed?
  end

  def check_completion_status
    if current_question_index >= total_questions && !completed?
      complete!
    end
  end

  def generate_insights_async
    # This would be implemented with a background job
    # AuditInsightGenerationJob.perform_later(self) if completed?
  end
end
