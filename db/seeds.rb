# Credit Packs

three_months = CreditPack.create(cents: 1_500, cr: 7_500)
six_months   = CreditPack.create(cents: 3_000, cr: 15_000)
one_year     = CreditPack.create(cents: 4_500, cr: 22_500)


# Games

minecraft = Game.create(
  name: 'Minecraft'
)


# Users

chris = User.new(
  username: 'chrislloyd',
  email: 'christopher.lloyd@gmail.com',
  facebook_uid: '219000855'
)

chris.skip_confirmation!
chris.password, chris.password_confirmation = 'password'
chris.admin = true

chris.players.new(game: minecraft, uid: 'christopher.lloyd@gmail.com')

chris.save


dave = User.new(
  username: 'whatupdave',
  email: 'dave@snappyco.de',
  facebook_uid: '709100496'
)

dave.skip_confirmation!
dave.password, dave.password_confirmation = 'password'
dave.admin = true

dave.players.new(game: minecraft, uid: 'dave@snappyco.de')

dave.save!
