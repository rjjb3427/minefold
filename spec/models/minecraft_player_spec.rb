require 'spec_helper'

describe MinecraftPlayer do

  it { should belong_to(:user) }


# ---
# Identity


  it { should have_field(:username) }
  # it { should validate_exclusion_of(:username).in(subject.class.blacklist) }
  it { should validate_length_of(:username).within(1..16) }
  it { should validate_format_of(:username).with_format(/^\w+$/) }
  it { should validate_uniqueness_of(:username) }

  it { should have_field(:slug) }

  it "sets the slug when setting the username" do
    subject.username = 'Foobar_baz'
    subject.slug.should == 'foobar_baz'
  end


# ---
# Unlocking


  it { should have_field(:unlock_code) }

  it "has a random unlock code" do
    subject.unlock_code.should_not be_empty
  end

  it "is unlocked when a user is associated with it" do
    subject.should_not be_unlocked
    subject.user = Fabricate(:user)
    subject.should be_unlocked
  end


# ---
# Avatar


  it { should respond_to(:avatar) }

  it "fetches avatars from Mojang" do
    subject.should_receive(:remote_avatar_url=).with(kind_of(String))
    subject.fetch_avatar
  end


# ---
# Stats


  it { should have_field(:minutes_played).of_type(Integer).with_default_value_of(0) }

  it { should have_field(:last_connected_at).of_type(DateTime) }


end