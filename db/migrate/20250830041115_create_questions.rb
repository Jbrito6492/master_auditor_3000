class CreateQuestions < ActiveRecord::Migration[8.0]
  def change
    create_table :questions do |t|
      t.references :audit_template, null: false, foreign_key: true
      t.text :text, null: false
      t.text :speech_text
      t.integer :sequence, null: false
      t.integer :question_type, default: 0
      t.integer :max_response_seconds, default: 120
      t.json :expected_keywords
      t.json :followup_prompts

      t.timestamps
    end
    
    add_index :questions, [:audit_template_id, :sequence], unique: true
    add_index :questions, :question_type
  end
end
