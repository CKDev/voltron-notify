class Voltron::SmsJob < ActiveJob::Base

  discard_on ::Twilio::REST::RequestError

  def perform(sms)
    sms.send(:send_now)
  end

end