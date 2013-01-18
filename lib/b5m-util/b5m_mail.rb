require 'mail'

class B5mMail
  def self.send(opts)
    mail = Mail.new do
      from opts[:from]
      to opts[:to]
      subject opts[:subject]
      body opts[:body]
    end
    Net::SMTP.start(opts[:host]) do |smtp|
      smtp.send_message(mail.to_s, opts[:from], opts[:to])
  end
end
