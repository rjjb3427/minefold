require 'spec_helper'

describe User do

  it { should be_timestamped_document}
  it { should be_paranoid_document}


  it {should have_field(:email)}
  it {should have_field(:username)}
  it {should have_field(:safe_username)}
  it {should have_field(:slug)}

  it {should have_field(:plan)}

  it {should have_field(:host)}

  it {should have_field(:credits).of_type(Integer)}
  it {should have_field(:minutes_played).of_type(Integer).with_default_value_of(0)}
  it {should embed_many(:credit_events)}
  it {should embed_one(:card)}

  it {should belong_to(:invite)}

  it {should belong_to(:current_world).of_type(World).as_inverse_of(nil)}
  it {should reference_many(:created_worlds).of_type(World).as_inverse_of(:creator)}

  it {should reference_and_be_referenced_in_many(:whitelisted_worlds).of_type(World)}

# Validations

  it { should validate_uniqueness_of(:email).case_insensitive}
  it { should validate_uniqueness_of(:username).case_insensitive}
  it { should validate_confirmation_of(:password)}
  it { should validate_numericality_of(:credits)}
  it { should validate_numericality_of(:minutes_played).greater_than_or_equal_to(0)}

  let(:user) {build(:user)}


# Credits

  it "gives FREE_HOURS by default" do
    user.credits.should == (User::FREE_HOURS.hours / User::BILLING_PERIOD)
  end

  it "#minutes is the remaining minutes from the hour" do
    user.credits = 1
    user.minutes.should == 1
    user.credits = 61
    user.minutes.should == 1
  end


# Authentication

  it "#safe_username is set when changing a username" do
    user.username = ' FooBarBaz '
    user.safe_username.should == 'foobarbaz'
  end
  
# Referrals

  it { should belong_to(:referrer).of_type(User).as_inverse_of(:referrals) }
  it { should reference_many(:referrals).of_type(User).as_inverse_of(:referrer) }

end
