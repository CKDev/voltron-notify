module Voltron
  class Config

    def notify
      @notify ||= Notify.new
    end

    class Notify

      attr_accessor :use_queue, :store_requests

      # SMS config settings
      attr_accessor :sms_account_sid, :sms_auth_token, :sms_from

      # Email config settings
      attr_accessor :email_from, :default_mailer, :default_method, :default_template

      def initialize
        @use_queue ||= false
        @store_requests ||= true
        @email_from ||= 'no-reply@example.com'
        @default_mailer = Voltron::NotificationMailer
        @default_method = :notify
        @default_template = 'voltron/notification_mailer/notify.html.erb'
      end

    end
  end
end
