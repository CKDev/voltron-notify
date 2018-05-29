require 'twilio-ruby'

class Voltron::Notification::SmsNotification < ActiveRecord::Base

  include Rails.application.routes.url_helpers

  has_many :attachments, as: :notification_attachable, class_name: '::Voltron::Notification::Attachment'

  belongs_to :notification, inverse_of: :sms_notifications

  after_initialize :setup

  before_create :send_now, unless: :use_queue?

  # We have a separate check for +created+ because we trigger +save+ within this callback,
  # and there are known issues of recursion when that is the case. See: https://github.com/rails/rails/issues/14493
  after_commit :send_later, on: :create, if: Proc.new { |n| n.send(:use_queue?) && !n.created }

  validates :status, presence: false, inclusion: { in: %w( accepted queued sending sent delivered received failed undelivered unknown ), message: I18n.t('voltron.notification.sms.status_invalid') }, on: :update

  validates_presence_of :to, message: I18n.t('voltron.notification.sms.to_blank')

  validates_presence_of :from, message: I18n.t('voltron.notification.sms.from_blank')

  validates_presence_of :message, message: I18n.t('voltron.notification.sms.message_blank')

  validate :valid_phone_number

  attr_accessor :created

  def request
    Voltron::Notification.format_output_of(request_json)
  end

  def response
    Voltron::Notification.format_output_of(response_json)
  end

  # Establish that we will perform the job immediately. Will cause +send_now+ to be called instead when saved
  def deliver_now
    @job_options = {}
    @job_method = :perform_now
  end

  # Establish that the job should be enqueued, and set the options
  def deliver_later(options={})
    @job_options = options
    @job_method = :perform_later
  end

  def attach(*urls)
    urls.flatten.each do |url|
      if url.starts_with? 'http'
        attachments.build attachment: url
      else
        attachments.build attachment: Voltron.config.base_url + ActionController::Base.helpers.asset_url(url)
      end
    end
  end

  def valid_phone?
    begin
      to_formatted
      true
    rescue ::Twilio::REST::RequestError => e
      Voltron.log e.message, 'Notify', Voltron::Notify::LOG_COLOR
      false
    end
  end

  private

    # Sends the SMS message
    def send_now
      @request = request
      @response = response

      all_attachments = attachments.map(&:attachment)

      # If sending more than 1 attachment, iterate through all but one attachment and send each without a body...
      if all_attachments.count > 1
        loop do
          break if all_attachments.count == 1
          client.messages.create({ from: from_formatted, to: to_formatted, media_url: all_attachments.shift, status_callback: callback_url }.compact)
          @request << Rack::Utils.parse_nested_query(client.last_request.body)
          @response << JSON.parse(client.last_response.body)
        end
      end

      # ... Then send the last attachment (if any) with the actual text body. This way we're not sending multiple SMS's with same body
      client.messages.create({ from: from_formatted, to: to_formatted, body: message, media_url: all_attachments.shift, status_callback: callback_url }.compact)
      @request << Rack::Utils.parse_nested_query(client.last_request.body)
      @response << JSON.parse(client.last_response.body)
      after_deliver
    end

    # Enqueue a job to deliver the SMS message, with options defined by calls to +deliver_later+
    def send_later
      @request << Voltron::SmsJob.set(default_options.merge(job_options)).send(job_method, self)
      after_deliver
    end

    def setup
      @request = []
      @response = []
    end

    def job_options
      @job_options ||= {}
    end

    def job_method
      @job_method ||= :perform_later
    end

    def default_options
      notification.notifyable.class.instance_variable_get('@_notification_defaults').try(:[], :sms) || {}
    end

    def after_deliver
      @created = true
      @job_options = nil
      @job_method = nil
      self.request_json = @request.to_json
      self.response_json = @response.to_json
      self.sid = response.first.try(:[], :sid)
      self.status = response.first.try(:[], :status) || 'unknown'

      # if use_queue?, meaning if this was sent via ActiveJob, we need to save ourself
      # since we got to here within after_create, meaning setting the attributes alone won't cut it
      self.save if use_queue?
    end

    def callback_url
      url = try(:update_voltron_notification_url, host: Voltron.config.base_url).to_s
      # Don't allow local or blank urls
      return nil if url.include?('localhost') || url.include?('127.0.0.1') || url.blank?
      url
    end

    def valid_phone_number
      errors.add :to, I18n.t('voltron.notification.sms.invalid_phone', number: to) unless valid_phone?
    end

    def use_queue?
      Voltron.config.notify.use_queue
    end

    def to_formatted
      format to || notification.notifyable.try(:phone)
    end

    def from_formatted
      format from
    end

    def format(input)
      # Try to format the number via Twilio's api
      raise ::Twilio::REST::RequestError.new('Phone number cannot be blank') if input.blank?
      number = lookup.phone_numbers.get input.to_s
      number.phone_number
    end

    def client
      @client ||= ::Twilio::REST::Client.new Voltron.config.notify.sms_account_sid, Voltron.config.notify.sms_auth_token
    end

    def lookup
      @lookup ||= ::Twilio::REST::LookupsClient.new Voltron.config.notify.sms_account_sid, Voltron.config.notify.sms_auth_token
    end

end
