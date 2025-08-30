class CreateAuditInsights < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_insights do |t|
      t.references :audit_session, null: false, foreign_key: true
      t.text :summary
      t.json :key_findings
      t.json :risk_indicators
      t.float :overall_score
      t.integer :confidence_level, default: 1

      t.timestamps
    end

    add_index :audit_insights, :overall_score
    add_index :audit_insights, :confidence_level
  end
end
