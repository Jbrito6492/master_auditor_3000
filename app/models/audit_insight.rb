class AuditInsight < ApplicationRecord
  # Associations
  belongs_to :audit_session
  
  # Delegations
  delegate :user, :audit_template, :responses, to: :audit_session

  # Enums
  enum :confidence_level, {
    low: 0,
    medium: 1,
    high: 2
  }

  # Validations
  validates :audit_session_id, uniqueness: true
  validates :confidence_level, presence: true
  validates :overall_score, numericality: { in: 0.0..100.0 }, allow_nil: true
  validates :summary, presence: true
  
  validate :audit_session_must_be_completed
  validate :valid_json_structure

  # Scopes
  scope :high_confidence, -> { where(confidence_level: :high) }
  scope :by_score_range, ->(min, max) { where(overall_score: min..max) }
  scope :recent, -> { joins(:audit_session).where('audit_sessions.completed_at > ?', 30.days.ago) }
  scope :with_risks, -> { where("JSON_LENGTH(risk_indicators) > 0") }

  # Callbacks
  before_validation :set_defaults, on: :create
  after_create :notify_stakeholders, if: -> { has_high_risk_indicators? }

  # Instance methods
  def risk_level
    return 'low' if overall_score.nil? || overall_score >= 80
    return 'high' if overall_score < 40
    'medium'
  end

  def risk_color
    case risk_level
    when 'low' then 'green'
    when 'medium' then 'yellow' 
    when 'high' then 'red'
    end
  end

  def has_risks?
    risk_indicators.present? && risk_indicators.any?
  end

  def high_priority_risks
    return [] unless risk_indicators.is_a?(Array)
    
    risk_indicators.select { |risk| risk.dig('severity') == 'high' }
  end

  def medium_priority_risks  
    return [] unless risk_indicators.is_a?(Array)
    
    risk_indicators.select { |risk| risk.dig('severity') == 'medium' }
  end

  def total_risk_count
    risk_indicators&.length || 0
  end

  def key_findings_summary
    return [] unless key_findings.is_a?(Array)
    
    key_findings.first(5) # Show top 5 findings
  end

  def recommendations
    return [] unless key_findings.is_a?(Hash) && key_findings['recommendations']
    
    key_findings['recommendations']
  end

  def compliance_score
    key_findings.dig('compliance', 'score') || overall_score
  end

  def areas_of_concern
    concerns = []
    
    # Add high-risk indicators
    concerns.concat(high_priority_risks.map { |r| r['description'] })
    
    # Add low-confidence responses
    low_confidence_responses = responses.where('transcription_confidence < ?', 0.5)
    if low_confidence_responses.any?
      concerns << "#{low_confidence_responses.count} responses with low transcription confidence"
    end
    
    # Add missing responses
    missing_responses = audit_template.questions.count - responses.count
    if missing_responses > 0
      concerns << "#{missing_responses} unanswered questions"
    end
    
    concerns
  end

  def strengths
    strengths = []
    
    # High overall score
    strengths << "Strong overall audit score (#{overall_score.round}%)" if overall_score && overall_score >= 80
    
    # Complete responses
    if responses.count == audit_template.questions.count
      strengths << "All questions answered completely"
    end
    
    # High confidence transcriptions
    high_confidence_count = responses.where('transcription_confidence >= ?', 0.8).count
    if high_confidence_count > responses.count * 0.8
      strengths << "High-quality audio responses"
    end
    
    # Extract positive findings
    if key_findings.is_a?(Hash) && key_findings['strengths']
      strengths.concat(key_findings['strengths'])
    end
    
    strengths
  end

  def action_items
    items = []
    
    # Address high-priority risks
    high_priority_risks.each do |risk|
      items << {
        priority: 'high',
        action: risk['recommended_action'] || "Address #{risk['description']}",
        category: risk['category'] || 'risk_mitigation'
      }
    end
    
    # Follow up on unclear responses
    responses.requiring_clarification.each do |response|
      items << {
        priority: 'medium',
        action: "Clarify response to: #{response.question.text.truncate(50)}",
        category: 'clarification'
      }
    end
    
    # Extract action items from key findings
    if key_findings.is_a?(Hash) && key_findings['action_items']
      key_findings['action_items'].each do |item|
        items << item.symbolize_keys
      end
    end
    
    items.sort_by { |item| item[:priority] == 'high' ? 0 : 1 }
  end

  def generate_report_data
    {
      session_id: audit_session.id,
      template_name: audit_template.name,
      completed_at: audit_session.completed_at,
      duration_minutes: audit_session.duration_in_minutes,
      overall_score: overall_score,
      risk_level: risk_level,
      confidence_level: confidence_level,
      summary: summary,
      key_findings: key_findings_summary,
      risks: {
        total: total_risk_count,
        high_priority: high_priority_risks.length,
        medium_priority: medium_priority_risks.length
      },
      areas_of_concern: areas_of_concern,
      strengths: strengths,
      action_items: action_items,
      responses_summary: {
        total: responses.count,
        high_confidence: responses.where('transcription_confidence >= ?', 0.8).count,
        requiring_review: responses.requiring_clarification.count
      }
    }
  end

  def has_high_risk_indicators?
    high_priority_risks.any? || (overall_score && overall_score < 40)
  end

  def update_insights(new_summary, new_findings = {}, new_risks = [], new_score = nil)
    update!(
      summary: new_summary,
      key_findings: new_findings,
      risk_indicators: new_risks,
      overall_score: new_score,
      confidence_level: calculate_confidence_level(new_score, new_risks)
    )
  end

  # Class methods
  def self.generate_for_session(session)
    return nil unless session.completed?
    
    # This would typically call an AI service to analyze the session
    insight = create!(
      audit_session: session,
      summary: generate_summary(session),
      key_findings: extract_key_findings(session),
      risk_indicators: identify_risks(session),
      overall_score: calculate_overall_score(session)
    )
    
    insight
  end

  def self.generate_summary(session)
    responses_count = session.responses.count
    template_name = session.audit_template.name
    duration = session.duration_in_minutes
    
    "Completed #{template_name} audit with #{responses_count} responses in #{duration} minutes. " \
    "Overall compliance appears #{session.completion_rate > 90 ? 'strong' : 'adequate'} with " \
    "#{session.responses.requiring_clarification.count} items requiring follow-up."
  end

  def self.extract_key_findings(session)
    {
      completion_rate: session.completion_rate,
      average_response_quality: session.responses.average(&:response_quality_score),
      common_themes: extract_common_themes(session),
      compliance_indicators: assess_compliance(session)
    }
  end

  def self.identify_risks(session)
    risks = []
    
    # Low completion rate
    if session.completion_rate < 80
      risks << {
        'category' => 'completion',
        'severity' => 'medium',
        'description' => 'Incomplete audit responses',
        'recommended_action' => 'Follow up on missing responses'
      }
    end
    
    # Multiple low-confidence responses
    low_confidence_count = session.responses.where('transcription_confidence < ?', 0.5).count
    if low_confidence_count > session.responses.count * 0.3
      risks << {
        'category' => 'data_quality',
        'severity' => 'high',
        'description' => 'Multiple responses with poor audio quality',
        'recommended_action' => 'Re-record unclear responses'
      }
    end
    
    risks
  end

  def self.calculate_overall_score(session)
    return 0 if session.responses.empty?
    
    # Weighted score based on multiple factors
    completion_score = session.completion_rate
    quality_score = session.responses.average(&:response_quality_score) || 0
    confidence_score = (session.responses.average(:transcription_confidence) || 0) * 100
    
    # Weighted average
    (completion_score * 0.4 + quality_score * 0.4 + confidence_score * 0.2).round(1)
  end

  private

  def set_defaults
    self.confidence_level ||= calculate_confidence_level(overall_score, risk_indicators)
  end

  def calculate_confidence_level(score, risks)
    risk_count = risks&.length || 0
    
    if score && score >= 80 && risk_count == 0
      :high
    elsif score && score >= 60 && risk_count <= 2
      :medium
    else
      :low
    end
  end

  def audit_session_must_be_completed
    return unless audit_session
    
    unless audit_session.completed?
      errors.add(:audit_session, 'must be completed before generating insights')
    end
  end

  def valid_json_structure
    validate_json_field(:key_findings, 'Key findings must be valid JSON')
    validate_json_field(:risk_indicators, 'Risk indicators must be valid JSON array')
  end

  def validate_json_field(field_name, error_message)
    field_value = send(field_name)
    return if field_value.blank?
    
    unless field_value.is_a?(Hash) || field_value.is_a?(Array)
      errors.add(field_name, error_message)
    end
  end

  def notify_stakeholders
    # This would be implemented to send notifications for high-risk audits
    # HighRiskAuditNotificationJob.perform_later(self)
  end

  def self.extract_common_themes(session)
    # Simple keyword analysis across all responses
    all_text = session.responses.pluck(:transcribed_text).join(' ')
    return [] if all_text.blank?
    
    # This is a simplified implementation - would use NLP in production
    words = all_text.downcase.split(/\W+/)
    stop_words = %w[the a an and or but in on at to for of with by is are was were]
    
    (words - stop_words)
      .select { |w| w.length > 4 }
      .tally
      .sort_by { |k, v| -v }
      .first(10)
      .map { |word, count| { theme: word, frequency: count } }
  end

  def self.assess_compliance(session)
    # Simple compliance assessment based on response completeness and quality
    {
      completeness: session.completion_rate,
      quality: session.responses.average(&:response_quality_score) || 0,
      timeliness: session.duration_in_minutes <= session.audit_template.estimated_duration_minutes
    }
  end
end
