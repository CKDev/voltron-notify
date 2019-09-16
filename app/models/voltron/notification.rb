module Voltron
  class Notification < ActiveRecord::Base

    belongs_to :notifyable, polymorphic: true, inverse_of: :notifications

    has_many :sms_notifications, inverse_of: :notification, validate: true, autosave: true

    has_many :email_notifications, inverse_of: :notification, validate: true, autosave: true

    before_validation :prepare

    PERMITTED_ATTRIBUTES = [:to, :from, :body]

    def email(subject, options={}, &block)
      # Get the remaining args as params, that will eventually become assigns in the mailer template
      params = { subject: subject, notifyable.class.name.downcase => notifyable }.compact.merge(options)

      # Build the options hash from the provided arguments
      options = { subject: subject }.merge(options.select { |k, _| PERMITTED_ATTRIBUTES.include?(k.to_sym) })

      # Build a new SMS notification object
      notification_email = email_notifications.build(options)

      # Set the email vars (assigns)
      notification_email.vars = params

      # If a block is provided, allow calls to methods like `attach`
      notification_email.instance_exec(&block) if block_given?

      # Return the email notification instance
      notification_email
    end

    def sms(message, options={}, &block)
      # Build the options hash from the provided arguments
      options = { message: message, from: Voltron.config.notify.sms_from }.merge(options)

      # Build a new SMS notification object
      notification_sms = sms_notifications.build(options)

      # If a block is provided, allow calls to methods like `attach`
      notification_sms.instance_exec(&block) if block_given?

      # Return the SMS notification instance
      notification_sms
    end

    # Called from the before_validation callback within `notifyable`
    # makes one final pass to set the email and phone as the to attribute
    # If already set however, this does nothing. We do this because simply calling
    # `notifyable` here returns nil until it's actually saved
    def to(email, phone)
      email_notifications.each { |n| n.to ||= email }
      sms_notifications.each { |n| n.to ||= phone }
    end

    def self.format_output_of(json)
      # Ensure returned object is an array of response hashes, for consistency
      out = Array.wrap((JSON.parse(json) rescue nil)).compact
      out.map { |h| h.with_indifferent_access }
    end

    private

      def prepare
        # Set the to value for both the email and phone, if any on this model
        # This method is also called from the before_validation block in the notify module
        # but we do it here in case the notification was created using resource.create
        # instead of resource.build -> resource.save
        to notifyable.try(:email), notifyable.try(:phone)
      end
  end
end
