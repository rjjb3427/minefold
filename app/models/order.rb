class Order
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paranoia

  belongs_to :user
  embeds_many :transactions

  # TODO: Store credits / cost etc. Needs seperate billing step.

  def process_payment!
    if transactions.last.completed?
      user.increment_credits! transactions.last.credits
    end
  end

  def status
    transactions.last.try(:status) || :pending
  end

  def credits
    transactions.last.credits
  end

  def hours
    transactions.last.hours
  end

  def gross
    transactions.sum(:gross)
  end

  def fee
    transactions.sum(:fee)
  end

end
