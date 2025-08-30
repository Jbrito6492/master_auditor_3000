class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :name
      t.datetime :last_audit_at
      t.string :preferred_voice, default: 'en-US-Neural2-C'
      t.string :preferred_language, default: 'en-US'
      t.boolean :speech_enabled, default: true

      t.timestamps
    end
    
    add_index :users, :email, unique: true
  end
end
