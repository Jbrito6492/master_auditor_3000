class CreateResponses < ActiveRecord::Migration[8.0]
  def change
    create_table :responses do |t|
      t.references :audit_session, null: false, foreign_key: true
      t.references :question, null: false, foreign_key: true
      t.text :transcribed_text
      t.integer :original_audio_duration_seconds
      t.datetime :responded_at
      t.integer :transcription_status, default: 0
      t.float :transcription_confidence
      t.json :speech_analysis
      t.boolean :requires_clarification, default: false
      t.text :clarification_notes

      t.timestamps
    end
    
    add_index :responses, [:audit_session_id, :question_id], unique: true
    add_index :responses, :transcription_status
    add_index :responses, :responded_at
  end
end
