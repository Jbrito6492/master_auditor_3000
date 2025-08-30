class Response < ApplicationRecord
  # Associations
  belongs_to :audit_session
  belongs_to :question
  has_one_attached :audio_recording

  # Enums
  enum :transcription_status, {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3
  }

  # Validations
  validates :audit_session_id, uniqueness: { scope: :question_id, message: 'has already been answered' }
  validates :transcription_status, presence: true
  validates :transcribed_text, presence: true, if: -> { completed? }
  validates :original_audio_duration_seconds, numericality: { greater_than: 0 }, if: -> { audio_recording.attached? }
  validates :transcription_confidence, numericality: { in: 0.0..1.0 }, allow_nil: true

  # Scopes
  scope :with_audio, -> { joins(:audio_recording_attachment) }
  scope :transcribed, -> { where(transcription_status: :completed) }
  scope :by_confidence, ->(min_confidence) { where('transcription_confidence >= ?', min_confidence) }
  scope :recent, -> { where('responded_at > ?', 30.days.ago) }
  scope :requiring_clarification, -> { where(requires_clarification: true) }

  # Callbacks
  before_validation :set_defaults, on: :create
  after_create :process_audio_async, if: -> { audio_recording.attached? }
  after_update :check_transcription_quality, if: -> { saved_change_to_transcription_status? && completed? }

  # Instance methods
  def user
    audit_session.user
  end

  def audit_template
    audit_session.audit_template
  end

  def has_audio?
    audio_recording.attached?
  end

  def audio_file_size
    return 0 unless has_audio?
    audio_recording.blob.byte_size
  end

  def audio_file_url
    return nil unless has_audio?
    Rails.application.routes.url_helpers.rails_blob_path(audio_recording, only_path: true)
  end

  def duration_in_seconds
    original_audio_duration_seconds || estimated_duration_from_text
  end

  def is_high_confidence?
    transcription_confidence && transcription_confidence >= 0.8
  end

  def is_low_confidence?
    transcription_confidence && transcription_confidence < 0.5
  end

  def word_count
    return 0 if transcribed_text.blank?
    transcribed_text.split(/\s+/).length
  end

  def character_count
    transcribed_text&.length || 0
  end

  def response_quality_score
    return 0 unless transcribed_text.present?
    
    score = 0
    
    # Base score for having text
    score += 20
    
    # Confidence score (0-40 points)
    score += (transcription_confidence || 0) * 40
    
    # Length score (0-20 points) - optimal around 50-200 words
    words = word_count
    if words.between?(10, 300)
      length_score = [20 - (words - 100).abs * 0.1, 0].max
      score += length_score
    end
    
    # Keyword matching (0-20 points)
    if question.expected_keywords.present?
      matched_keywords = question.expected_keywords.count do |keyword|
        transcribed_text.downcase.include?(keyword.downcase)
      end
      keyword_percentage = matched_keywords.to_f / question.expected_keywords.length
      score += keyword_percentage * 20
    else
      score += 10 # Default bonus if no keywords specified
    end
    
    [score.round, 100].min
  end

  def needs_review?
    is_low_confidence? || requires_clarification? || response_quality_score < 40
  end

  def mark_for_clarification!(notes = nil)
    update!(
      requires_clarification: true,
      clarification_notes: notes
    )
  end

  def clear_clarification_flag!
    update!(
      requires_clarification: false,
      clarification_notes: nil
    )
  end

  def process_transcription(text, confidence = nil, analysis = nil)
    update!(
      transcribed_text: text,
      transcription_confidence: confidence,
      speech_analysis: analysis,
      transcription_status: :completed,
      responded_at: Time.current
    )
    
    # Advance session to next question if this response is satisfactory
    audit_session.advance_to_next_question! unless needs_review?
  end

  def fail_transcription!(error_message)
    update!(
      transcription_status: :failed,
      clarification_notes: "Transcription failed: #{error_message}"
    )
  end

  def retranscribe!
    return false unless has_audio?
    
    update!(transcription_status: :pending)
    process_audio_async
    true
  end

  # Analysis methods
  def extract_keywords
    return [] if transcribed_text.blank?
    
    # Simple keyword extraction - could be enhanced with NLP
    words = transcribed_text.downcase.split(/\W+/)
    stop_words = %w[the a an and or but in on at to for of with by]
    
    (words - stop_words).select { |w| w.length > 3 }.tally.sort_by { |k, v| -v }.first(10).map(&:first)
  end

  def sentiment_analysis
    return 'neutral' if transcribed_text.blank?
    
    # Simple sentiment analysis - could be enhanced with ML
    positive_words = %w[good great excellent satisfied happy pleased positive yes agree]
    negative_words = %w[bad terrible awful disappointed unhappy negative no disagree]
    
    words = transcribed_text.downcase.split(/\W+/)
    
    positive_count = (words & positive_words).length
    negative_count = (words & negative_words).length
    
    if positive_count > negative_count
      'positive'
    elsif negative_count > positive_count
      'negative'  
    else
      'neutral'
    end
  end

  private

  def set_defaults
    self.transcription_status ||= :pending
    self.requires_clarification ||= false
    self.responded_at ||= Time.current if transcribed_text.present?
  end

  def estimated_duration_from_text
    return 0 if transcribed_text.blank?
    # Rough estimate: average speaking rate is ~150 words per minute
    (word_count / 2.5).round # Convert to seconds
  end

  def process_audio_async
    # This would be implemented with a background job
    # SpeechTranscriptionJob.perform_later(self)
    update!(transcription_status: :processing)
  end

  def check_transcription_quality
    # Flag for review if confidence is too low
    if is_low_confidence? && !requires_clarification?
      mark_for_clarification!("Low transcription confidence: #{(transcription_confidence * 100).round}%")
    end
  end
end
