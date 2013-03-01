require 'mail'

class B5mMail
  def self.send(opts)
    from_str = opts[:from]
    unless opts[:from_alias].nil?
      from_str = "#{opts[:from_alias]} <#{from_str}>"
    end
    mail = Mail.new do
      from from_str
      to opts[:to]
      subject opts[:subject]
      body opts[:body]
    end
    #smtp_from = opts[:from]
    user = ENV['USER']
    hostname = ENV['HOSTNAME']
    user = 'lscm' if user.nil?
    hostname = 'B5M' if hostname.nil?
    smtp_from = "#{user}@#{hostname}.localdomain"
    Net::SMTP.start(opts[:host]) do |smtp|
      smtp.send_message(mail.to_s, smtp_from, opts[:to])
    end
  end
end
