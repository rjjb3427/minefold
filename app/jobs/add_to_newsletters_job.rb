class AddToNewslettersJob < Job
  @queue = :low

  attr_reader :user

  def initialize(user_id)
    @user = User.unscoped.find(user_id)
  end

  def perform
    add_to_mailgun_list('newsletters', user.email, user.name || user.username)
  end

  def add_to_mailgun_list(list, email, name)
    list = "newsletters"
    endpoint = "https://api:#{ENV['MAILGUN_API_KEY']}@api.mailgun.net/v2"
    url = "#{endpoint}/lists/#{list}@#{ENV['MAILGUN_DOMAIN']}/members"

    RestClient.post(url, address: email, name: name)
  end
end
