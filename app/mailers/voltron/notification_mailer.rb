require 'open-uri'

class Voltron::NotificationMailer < ApplicationMailer
  default from: Voltron.config.notify.email_from

  def notify(mail_args, var_args = {}, attachment_args = {})
    # Make all passed in variables instance variables so they can be used in the template
    var_args.each { |name, value| instance_variable_set "@#{name}", value }

    # Add all of the attachments
    attachment_args.each { |name, file| attachments[name] = open(file).read }

    mail mail_args
  end
end
