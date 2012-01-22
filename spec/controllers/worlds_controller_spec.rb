require 'spec_helper'

describe WorldsController do
  render_views

  describe "#create" do
    signin_as { Fabricate(:user) }

    before {
      post :create, world: {
        name: 'minebnb'
      }
    }

    it { response.should redirect_to(user_world_path(current_user.slug, 'minebnb')) }
  end

  describe "#show" do
    let(:world) { Fabricate(:world) }

    it "renders" do
      get :show, user_id: world.creator.slug, id: world.slug
      response.should be_successful
    end

    context 'signed in as the creator' do
      signin_as { world.creator }
    end

    context 'signed in as an op' do
      # signin_as { subject.creator }
    end

    context 'signed in as a player' do
      # signin_as { subject.creator }
    end
  end

  describe '#clone' do

  end
end
