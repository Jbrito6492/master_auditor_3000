class CreateAuditSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_sessions do |t|
      t.references :user, null: true, foreign_key: true  # Allow anonymous sessions
      t.references :audit_template, null: false, foreign_key: true
      t.integer :status, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      t.string :session_token, null: false
      t.integer :current_question_index, default: 0
      t.string :preferred_voice, default: 'en-US-Neural2-C'
      t.boolean :speech_enabled, default: true

      t.timestamps
    end

    add_index :audit_sessions, :session_token, unique: true
    add_index :audit_sessions, :status
  end
end
