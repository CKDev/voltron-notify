class Voltron::Notification::Attachment < ActiveRecord::Base

  belongs_to :notification_attachable, polymorphic: true, inverse_of: :attachments

end
