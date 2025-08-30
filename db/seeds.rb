# Create sample audit templates and questions for speech-to-speech auditing

puts "Creating sample audit templates..."

# Daily Reflection Template
reflection_template = AuditTemplate.create!(
  name: "Daily Reflection",
  description: "Personal daily reflection covering personal control, alignment, goals, challenges, gratitude, and current learning.",
  estimated_duration_minutes: 10,
  intro_message: "Welcome to your daily reflection. I'll be asking you six questions to help you process your day. Please speak naturally and take your time with each response.",
  outro_message: "Thank you for completing your daily reflection. Your insights will help you stay aligned with your values and goals.",
  default_voice: "en-US-Neural2-C"
)

reflection_questions = [
  {
    text: "🏆 What was within my control today, and how did I act accordingly?",
    speech_text: "First question: What was within my control today, and how did I act accordingly?",
    question_type: :open_ended,
    max_response_seconds: 180,
    expected_keywords: [ "control", "decisions", "actions", "response", "choice", "influence", "agency" ]
  },
  {
    text: "✨ Did I embody my personal alignment today? Where did I succeed or fall short?",
    speech_text: "Second question: Did I embody my personal alignment today? Where did I succeed or fall short?",
    question_type: :open_ended,
    max_response_seconds: 180,
    expected_keywords: [ "alignment", "values", "authentic", "integrity", "consistent", "principles", "character" ]
  },
  {
    text: "🎯 What was one action I took today that moved me closer to my highest goals?",
    speech_text: "Third question: What was one action I took today that moved me closer to my highest goals?",
    question_type: :open_ended,
    max_response_seconds: 150,
    expected_keywords: [ "action", "progress", "goals", "achievement", "step", "advance", "momentum" ]
  },
  {
    text: "⚡ What challenges did I face, and how did I respond?",
    speech_text: "Fourth question: What challenges did I face, and how did I respond?",
    question_type: :open_ended,
    max_response_seconds: 180,
    expected_keywords: [ "challenges", "obstacles", "difficulties", "problems", "response", "handled", "overcame" ]
  },
  {
    text: "🙏 What am I grateful for at the end of this day?",
    speech_text: "Fifth question: What am I grateful for at the end of this day?",
    question_type: :open_ended,
    max_response_seconds: 150,
    expected_keywords: [ "grateful", "thankful", "appreciate", "blessed", "positive", "good", "wonderful" ]
  },
  {
    text: "📚 Currently reading: [Book Title] by [Author]",
    speech_text: "Sixth question: What are you currently reading? Please share the book title and author, or tell me about any learning you're engaged in.",
    question_type: :open_ended,
    max_response_seconds: 120,
    expected_keywords: [ "reading", "book", "learning", "studying", "author", "title", "knowledge" ]
  }
]

reflection_questions.each_with_index do |q_data, index|
  reflection_template.questions.create!(
    text: q_data[:text],
    speech_text: q_data[:speech_text],
    sequence: index + 1,
    question_type: q_data[:question_type],
    max_response_seconds: q_data[:max_response_seconds],
    expected_keywords: q_data[:expected_keywords],
    followup_prompts: [
      "Could you tell me more about that?",
      "Can you expand on that thought?",
      "What else comes to mind about this?"
    ]
  )
end

puts "Created Daily Reflection template with #{reflection_template.questions.count} questions"

# Business Health Check Template
business_template = AuditTemplate.create!(
  name: "Small Business Health Check",
  description: "Quick assessment of small business operations, finances, and growth opportunities.",
  estimated_duration_minutes: 20,
  intro_message: "Welcome to your business health check. I'll ask you several questions about your business operations, finances, and goals. Please provide detailed responses.",
  outro_message: "Thank you for completing your business health check. We'll analyze your responses and provide actionable insights to help grow your business.",
  default_voice: "en-US-Neural2-D"
)

business_questions = [
  {
    text: "Please describe your business, what you do, and how long you've been operating.",
    speech_text: "Please describe your business. What do you do, and how long have you been operating?",
    question_type: :open_ended,
    max_response_seconds: 180
  },
  {
    text: "How has your business performance been over the past 12 months compared to your expectations?",
    speech_text: "How has your business performance been over the past 12 months compared to your expectations?",
    question_type: :open_ended,
    max_response_seconds: 150
  },
  {
    text: "What are your biggest business challenges or obstacles right now?",
    speech_text: "What are your biggest business challenges or obstacles right now?",
    question_type: :open_ended,
    max_response_seconds: 180
  },
  {
    text: "How do you currently find and attract new customers or clients?",
    speech_text: "How do you currently find and attract new customers or clients?",
    question_type: :open_ended,
    max_response_seconds: 120
  },
  {
    text: "What are your business goals for the next year, and what support do you need to achieve them?",
    speech_text: "What are your business goals for the next year? What support do you need to achieve them?",
    question_type: :open_ended,
    max_response_seconds: 180
  }
]

business_questions.each_with_index do |q_data, index|
  business_template.questions.create!(
    text: q_data[:text],
    speech_text: q_data[:speech_text],
    sequence: index + 1,
    question_type: q_data[:question_type],
    max_response_seconds: q_data[:max_response_seconds],
    followup_prompts: [
      "Can you elaborate on that?",
      "What specific steps are you taking?",
      "How is that impacting your business?"
    ]
  )
end

puts "Created Business Health Check template with #{business_template.questions.count} questions"

# Create a sample user
sample_user = User.create!(
  email: "demo@example.com",
  name: "Demo User",
  preferred_voice: "en-US-Neural2-C",
  preferred_language: "en-US",
  speech_enabled: true
)

puts "Created sample user: #{sample_user.email}"

# Create a sample audit session (completed)
sample_session = AuditSession.create!(
  user: sample_user,
  audit_template: reflection_template,
  status: :completed,
  started_at: 2.hours.ago,
  completed_at: 1.hour.ago,
  session_token: AuditSession.generate_token,
  current_question_index: reflection_template.questions.count,
  preferred_voice: "en-US-Neural2-C",
  speech_enabled: true
)

# Create sample responses
reflection_template.questions.first(3).each_with_index do |question, index|
  sample_session.responses.create!(
    question: question,
    transcribed_text: case index
                      when 0 then "Today I had control over my morning routine, my work priorities, and how I responded to unexpected challenges. I started my day with meditation and planned my top three tasks. When a project deadline shifted, I stayed calm and adjusted my schedule rather than getting stressed about it."
                      when 1 then "I think I did well embodying my values of honesty and growth today. I gave direct but kind feedback to a colleague, which aligned with my value of authentic communication. However, I fell short on my commitment to physical health - I skipped my planned workout because I prioritized work tasks instead."
                      when 2 then "I spent 30 minutes learning a new programming framework that's directly relevant to a project I want to launch next month. This was a concrete step toward my goal of building my own software product. Even though it was just a small learning session, it felt meaningful because it was intentional progress."
                      end,
    original_audio_duration_seconds: [ 45, 38, 42 ][index],
    responded_at: (2.hours.ago + (index * 10).minutes),
    transcription_status: :completed,
    transcription_confidence: [ 0.91, 0.89, 0.93 ][index],
    speech_analysis: {
      volume: "good",
      clarity: "high",
      pace: "thoughtful",
      background_noise: "minimal"
    },
    requires_clarification: false
  )
end

puts "Created sample audit session with #{sample_session.responses.count} responses"

# Create sample audit insight
insight = AuditInsight.create!(
  audit_session: sample_session,
  summary: "Completed Daily Reflection with 3 thoughtful responses showing strong self-awareness and intentional living. Demonstrates good emotional regulation, value-based decision making, and consistent progress toward goals. Areas for growth identified in work-life balance and health commitments.",
  key_findings: {
    strengths: [
      "Strong emotional regulation when facing unexpected challenges",
      "Clear awareness of personal values and ability to act on them",
      "Consistent daily practices like meditation that support well-being",
      "Taking concrete action toward long-term goals with intentional learning"
    ],
    areas_for_improvement: [
      "Better integration of health commitments with work priorities",
      "Creating stronger boundaries to protect personal wellness time",
      "Developing systems to maintain healthy habits under pressure"
    ],
    recommendations: [
      "Schedule workout time as non-negotiable appointments",
      "Create if-then plans for maintaining health habits during busy periods",
      "Continue morning routine as it appears to be setting positive tone for the day",
      "Consider tracking progress on personal goals to maintain momentum"
    ]
  },
  risk_indicators: [
    {
      category: "work_life_balance",
      severity: "medium",
      description: "Tendency to sacrifice health commitments for work tasks",
      recommended_action: "Establish clearer boundaries and treat health time as sacred"
    }
  ],
  overall_score: 82.3,
  confidence_level: :high
)

puts "Created sample audit insight with overall score: #{insight.overall_score}"

puts "\n=== Seed Data Summary ==="
puts "Audit Templates: #{AuditTemplate.count}"
puts "Questions: #{Question.count}"
puts "Users: #{User.count}"
puts "Audit Sessions: #{AuditSession.count}"
puts "Responses: #{Response.count}"
puts "Audit Insights: #{AuditInsight.count}"
puts "\n✅ Database seeded successfully!"
puts "\nTo start a new audit session, visit the application and select one of the available templates."
