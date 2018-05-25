class CreateVoltronNotificationAttachments < ActiveRecord::Migration
  def change
    create_table :voltron_notification_attachments do |t|
      t.string :notification_attachable_type
      t.integer :notification_attachable_id
      t.string :attachment_name
      t.string :attachment

      t.timestamps null: false
    end
  end
end
