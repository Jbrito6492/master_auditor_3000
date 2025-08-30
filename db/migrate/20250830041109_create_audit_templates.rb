class CreateAuditTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_templates do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :active, default: true
      t.integer :estimated_duration_minutes
      t.text :intro_message
      t.text :outro_message
      t.string :default_voice, default: 'en-US-Neural2-C'

      t.timestamps
    end
    
    add_index :audit_templates, :active
    add_index :audit_templates, :name, unique: true
  end
end
