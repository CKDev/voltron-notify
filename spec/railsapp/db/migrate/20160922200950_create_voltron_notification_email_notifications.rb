class CreateVoltronNotificationEmailNotifications < ActiveRecord::Migration
  def change
    create_table :voltron_notification_email_notifications do |t|
      t.string :to
      t.string :from
      t.string :subject
      t.text   :body
      t.string :template_path
      t.string :template_name
      t.string :mailer_class
      t.string :mailer_method
      t.text :request_json
      t.text :response_json
      t.integer :notification_id
    end
  end
end
