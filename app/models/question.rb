class Question < ApplicationRecord
  # Associations
  belongs_to :audit_template
  has_many :responses, dependent: :destroy
  has_one_attached :audio_file

  # Enums
  enum :question_type, {
    open_ended: 0,
    yes_no: 1,
    multiple_choice: 2,
    numeric: 3
  }

  # Validations
  validates :text, presence: true
  validates :sequence, presence: true, uniqueness: { scope: :audit_template_id }
  validates :max_response_seconds, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 300 }
  validates :question_type, presence: true

  # Scopes
  scope :ordered, -> { order(:sequence) }
  scope :by_type, ->(type) { where(question_type: type) }
  scope :with_audio, -> { joins(:audio_file_attachment) }

  # Callbacks
  before_validation :set_defaults, on: :create
  before_validation :set_speech_text, if: -> { speech_text.blank? && text.present? }
  after_commit :generate_audio_file, on: :create, if: -> { should_generate_audio? }

  # Instance methods
  def display_text
    text
  end

  def speech_optimized_text
    speech_text.presence || optimize_text_for_speech(text)
  end

  def has_audio?
    audio_file.attached?
  end

  def audio_duration
    return 0 unless has_audio?
    # This would need to be calculated when audio is attached
    # For now, return estimated duration based on text length
    (speech_optimized_text.length / 10.0).round(1) # ~10 chars per second
  end

  def next_question
    audit_template.questions.where("sequence > ?", sequence).first
  end

  def previous_question
    audit_template.questions.where("sequence < ?", sequence).last
  end

  def response_for_session(session)
    responses.find_by(audit_session: session)
  end

  def expected_response_format
    case question_type
    when "yes_no"
      "Please answer yes or no"
    when "numeric"
      "Please provide a number"
    when "multiple_choice"
      "Please choose from the available options"
    else
      "Please provide your response"
    end
  end

  # Class methods
  def self.generate_sequence_for_template(template)
    template.questions.maximum(:sequence).to_i + 1
  end

  private

  def set_defaults
    self.max_response_seconds ||= 120
    self.question_type ||= :open_ended
    self.sequence ||= self.class.generate_sequence_for_template(audit_template) if audit_template
  end

  def set_speech_text
    self.speech_text = optimize_text_for_speech(text)
  end

  def optimize_text_for_speech(text)
    return text if text.blank?

    # Optimize text for text-to-speech
    optimized = text.dup

    # Replace common abbreviations with full words
    optimized.gsub!(/\bDr\./, "Doctor")
    optimized.gsub!(/\bMr\./, "Mister")
    optimized.gsub!(/\bMrs\./, "Misses")
    optimized.gsub!(/\bMs\./, "Miss")
    optimized.gsub!(/\betc\./, "etcetera")
    optimized.gsub!(/\bi\.e\./, "that is")
    optimized.gsub!(/\be\.g\./, "for example")

    # Add pauses after questions
    optimized.gsub!(/\?/, "? ... ")

    # Ensure proper sentence ending
    optimized += "." unless optimized.end_with?(".", "?", "!")

    optimized.strip
  end

  def should_generate_audio?
    # Generate audio for production or when specifically requested
    Rails.env.production? || ENV["GENERATE_QUESTION_AUDIO"] == "true"
  end

  def generate_audio_file
    # This would be implemented with a background job
    # SpeechSynthesisJob.perform_later(self) if should_generate_audio?
  end
end
